"""
Management command to run migrations on ALL tenant databases.

Usage:
    python manage.py migrate_all_tenants              # migrate all active tenants
    python manage.py migrate_all_tenants --all        # include inactive tenants
    python manage.py migrate_all_tenants --tenant=abc # migrate a single tenant by subdomain
    python manage.py migrate_all_tenants --parallel   # run migrations in parallel (faster)
"""
import copy
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand

from apps.users.models import Tenant


class Command(BaseCommand):
    help = "Run Django migrations on all tenant databases."

    def add_arguments(self, parser):
        parser.add_argument(
            "--all",
            action="store_true",
            default=False,
            help="Include inactive tenants (by default only active ones are migrated).",
        )
        parser.add_argument(
            "--tenant",
            type=str,
            default=None,
            help="Migrate a single tenant by subdomain.",
        )
        parser.add_argument(
            "--parallel",
            action="store_true",
            default=False,
            help="Run migrations in parallel threads (faster, but noisier output).",
        )
        parser.add_argument(
            "--workers",
            type=int,
            default=4,
            help="Number of parallel workers (default: 4). Only used with --parallel.",
        )

    def handle(self, *args, **options):
        # ── Resolve which tenants to migrate ──
        if options["tenant"]:
            tenants = list(
                Tenant.objects.filter(subdomain__iexact=options["tenant"])
            )
            if not tenants:
                self.stderr.write(
                    self.style.ERROR(
                        f"Tenant '{options['tenant']}' not found."
                    )
                )
                sys.exit(1)
        elif options["all"]:
            tenants = list(Tenant.objects.all())
        else:
            tenants = list(Tenant.objects.filter(is_active=True))

        if not tenants:
            self.stdout.write(self.style.WARNING("No tenants to migrate."))
            return

        self.stdout.write(
            self.style.MIGRATE_HEADING(
                f"Migrating {len(tenants)} tenant database(s)...\n"
            )
        )

        # ── Migrate ──
        if options["parallel"] and len(tenants) > 1:
            self._migrate_parallel(tenants, options["workers"])
        else:
            self._migrate_sequential(tenants)

    # ── Sequential ────────────────────────────────────────────────────────

    def _migrate_sequential(self, tenants):
        success, failed = 0, 0
        for tenant in tenants:
            ok = self._migrate_one(tenant)
            if ok:
                success += 1
            else:
                failed += 1

        self._print_summary(success, failed, len(tenants))

    # ── Parallel ──────────────────────────────────────────────────────────

    def _migrate_parallel(self, tenants, workers):
        success, failed = 0, 0
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(self._migrate_one, t): t for t in tenants
            }
            for future in as_completed(futures):
                if future.result():
                    success += 1
                else:
                    failed += 1

        self._print_summary(success, failed, len(tenants))

    # ── Single tenant migration ───────────────────────────────────────────

    def _migrate_one(self, tenant):
        """Register the tenant DB and run migrations. Returns True on success."""
        db_alias = f"tenant_{tenant.id}"
        db_name = tenant.db_name

        if not db_name:
            self.stderr.write(
                self.style.WARNING(
                    f"  SKIP  {tenant.subdomain} — no db_name configured"
                )
            )
            return False

        # Dynamically register the database
        default_db = settings.DATABASES["default"]
        if db_alias not in settings.DATABASES:
            db_config = copy.deepcopy(default_db)
            db_config.update(
                {
                    "NAME": db_name,
                    "USER": tenant.db_user or default_db.get("USER", ""),
                    "PASSWORD": tenant.db_password
                    or default_db.get("PASSWORD", ""),
                    "HOST": tenant.db_host or default_db.get("HOST", "localhost"),
                    "PORT": tenant.db_port or default_db.get("PORT", "5432"),
                    "ATOMIC_REQUESTS": False,
                }
            )
            settings.DATABASES[db_alias] = db_config

        self.stdout.write(f"  Migrating {tenant.subdomain} ({db_name}) ... ", ending="")
        start = time.time()

        try:
            call_command("migrate", database=db_alias, verbosity=0)
            elapsed = time.time() - start
            self.stdout.write(
                self.style.SUCCESS(f"OK ({elapsed:.1f}s)")
            )
            return True
        except Exception as exc:
            elapsed = time.time() - start
            self.stderr.write(
                self.style.ERROR(f"FAILED ({elapsed:.1f}s) — {exc}")
            )
            return False

    # ── Summary ───────────────────────────────────────────────────────────

    def _print_summary(self, success, failed, total):
        self.stdout.write("")
        if failed == 0:
            self.stdout.write(
                self.style.SUCCESS(
                    f"All {total} tenant(s) migrated successfully."
                )
            )
        else:
            self.stdout.write(
                self.style.WARNING(
                    f"Done: {success}/{total} succeeded, {failed} failed."
                )
            )
