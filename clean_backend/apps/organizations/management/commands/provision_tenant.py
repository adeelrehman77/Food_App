"""
Management command to provision a new tenant from the command line.

Creates the PostgreSQL database, runs migrations, and creates the admin user.

Usage:
    python manage.py provision_tenant \\
        --name "Ali Kitchen" \\
        --subdomain ali_kitchen \\
        --admin-email ali@example.com \\
        --admin-password secret123 \\
        --plan-id 1

    # Auto-generate password:
    python manage.py provision_tenant \\
        --name "Ali Kitchen" \\
        --subdomain ali_kitchen \\
        --admin-email ali@example.com
"""
import copy
import secrets
import sys
import time

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.db import connection as default_conn
from django.utils import timezone

from apps.organizations.models import ServicePlan
from apps.organizations.models_saas import TenantSubscription
from apps.users.models import Tenant
from core.db.router import set_current_db_alias, get_current_db_alias

User = get_user_model()


class Command(BaseCommand):
    help = "Provision a new tenant: create DB, run migrations, create admin user."

    def add_arguments(self, parser):
        parser.add_argument(
            "--name",
            type=str,
            required=True,
            help="Display name for the tenant/kitchen.",
        )
        parser.add_argument(
            "--subdomain",
            type=str,
            required=True,
            help="Subdomain identifier (lowercase, no spaces).",
        )
        parser.add_argument(
            "--admin-email",
            type=str,
            default="",
            help="Email for the tenant admin user.",
        )
        parser.add_argument(
            "--admin-password",
            type=str,
            default="",
            help="Password for the tenant admin (auto-generated if omitted).",
        )
        parser.add_argument(
            "--plan-id",
            type=int,
            default=None,
            help="ServicePlan ID to assign (optional).",
        )
        parser.add_argument(
            "--skip-migrate",
            action="store_true",
            default=False,
            help="Skip running migrations (useful if DB already exists).",
        )

    def handle(self, *args, **options):
        name = options["name"]
        subdomain = options["subdomain"].lower().strip()
        admin_email = options["admin_email"]
        admin_password = options["admin_password"] or secrets.token_urlsafe(12)
        plan_id = options["plan_id"]

        # ── Validate ──
        if Tenant.objects.filter(subdomain__iexact=subdomain).exists():
            raise CommandError(
                f"Tenant with subdomain '{subdomain}' already exists."
            )

        db_name = f"tenant_{subdomain}"
        default_db = settings.DATABASES["default"]
        db_user = default_db.get("USER", "")
        db_password = default_db.get("PASSWORD", "")
        db_host = default_db.get("HOST", "localhost")
        db_port = default_db.get("PORT", "5432")

        # ── Step 1: Create PostgreSQL database ──
        self.stdout.write(f"\n1. Creating database '{db_name}' ... ", ending="")
        try:
            with default_conn.cursor() as cursor:
                cursor.execute("COMMIT")  # CREATE DATABASE can't run in a tx
                cursor.execute(f'CREATE DATABASE "{db_name}"')
            self.stdout.write(self.style.SUCCESS("OK"))
        except Exception as exc:
            if "already exists" in str(exc):
                self.stdout.write(self.style.WARNING("already exists (reusing)"))
            else:
                self.stderr.write(self.style.ERROR(f"FAILED — {exc}"))
                sys.exit(1)

        # ── Step 2: Create tenant record ──
        self.stdout.write("2. Creating tenant record ... ", ending="")
        tenant = Tenant.objects.create(
            name=name,
            subdomain=subdomain,
            schema_name=subdomain,
            db_name=db_name,
            db_user=db_user,
            db_password=db_password,
            db_host=db_host,
            db_port=db_port,
            is_active=True,
        )
        self.stdout.write(self.style.SUCCESS(f"OK (id={tenant.id})"))

        # ── Step 3: Run migrations ──
        if not options["skip_migrate"]:
            self.stdout.write("3. Running migrations ... ", ending="")
            db_alias = f"tenant_{tenant.id}"
            db_config = copy.deepcopy(default_db)
            db_config.update(
                {
                    "NAME": db_name,
                    "USER": db_user,
                    "PASSWORD": db_password,
                    "HOST": db_host,
                    "PORT": db_port,
                    "ATOMIC_REQUESTS": False,
                }
            )
            settings.DATABASES[db_alias] = db_config

            start = time.time()
            try:
                call_command("migrate", database=db_alias, verbosity=0)
                elapsed = time.time() - start
                self.stdout.write(self.style.SUCCESS(f"OK ({elapsed:.1f}s)"))
            except Exception as exc:
                elapsed = time.time() - start
                self.stderr.write(
                    self.style.ERROR(f"FAILED ({elapsed:.1f}s) — {exc}")
                )
                self.stderr.write(
                    "  Tenant record was created but migrations failed. "
                    "Fix the issue and run: "
                    f"python manage.py migrate_all_tenants --tenant={subdomain}"
                )
        else:
            self.stdout.write("3. Skipping migrations (--skip-migrate)")

        # ── Step 4: Create admin user (in the TENANT database) ──
        self.stdout.write("4. Creating admin user in tenant DB ... ", ending="")
        base_username = (
            admin_email.split("@")[0] if admin_email else subdomain
        )
        username = base_username

        # Switch to tenant DB context so User.objects routes there
        old_alias = get_current_db_alias()
        set_current_db_alias(db_alias)
        try:
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1

            admin_user = User.objects.create_user(
                username=username,
                email=admin_email,
                password=admin_password,
                is_staff=True,
                is_active=True,
            )

            self.stdout.write(
                self.style.SUCCESS(f"OK (username={username}, id={admin_user.id})")
            )
        finally:
            set_current_db_alias(old_alias)

        # ── Step 5: Assign plan & create subscription ──
        if plan_id:
            self.stdout.write(
                f"5. Assigning plan (id={plan_id}) ... ", ending=""
            )
            try:
                plan = ServicePlan.objects.get(id=plan_id, is_active=True)
                tenant.service_plan = plan
                tenant.save(update_fields=["service_plan"])

                from datetime import timedelta

                now = timezone.now().date()
                TenantSubscription.objects.create(
                    tenant=tenant,
                    plan=plan,
                    status="trial",
                    billing_cycle="monthly",
                    current_period_start=now,
                    current_period_end=now + timedelta(days=plan.trial_days),
                    trial_end=now + timedelta(days=plan.trial_days),
                    next_invoice_date=now + timedelta(days=plan.trial_days),
                )
                self.stdout.write(self.style.SUCCESS(f"OK ({plan.name})"))
            except ServicePlan.DoesNotExist:
                self.stdout.write(
                    self.style.WARNING(
                        f"Plan id={plan_id} not found or inactive. Skipped."
                    )
                )
        else:
            self.stdout.write("5. No plan assigned (use --plan-id to assign)")

        # ── Summary ──
        self.stdout.write(
            self.style.MIGRATE_HEADING("\n── Tenant Provisioned ──")
        )
        self.stdout.write(f"  Name:      {name}")
        self.stdout.write(f"  Subdomain: {subdomain}")
        self.stdout.write(f"  Database:  {db_name}")
        self.stdout.write(f"  Admin:     {username} / {admin_email}")
        if not options["admin_password"]:
            self.stdout.write(
                self.style.WARNING(
                    f"  Password:  {admin_password}  (auto-generated, share securely!)"
                )
            )
        else:
            self.stdout.write("  Password:  ****  (as provided)")
        self.stdout.write("")
