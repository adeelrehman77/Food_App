"""
Delete all subscriptions (and related Orders, DeliveryStatus, etc.) for one or all tenant DBs.

CASCADE will also remove:
- Order, SubscriptionEditRequest (main)
- DeliveryStatus, DeliveryAssignment (driver)
- Delivery, KitchenOrder (via Order)

Usage:
    python manage.py clean_tenant_subscriptions --tenant=test_tenant   # one tenant by subdomain
    python manage.py clean_tenant_subscriptions --all                 # all active tenants
"""
import copy
import sys

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.main.models import Subscription
from apps.users.models import Tenant


class Command(BaseCommand):
    help = "Delete all subscriptions (and related orders, delivery statuses, etc.) for the given tenant(s)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--tenant",
            type=str,
            default=None,
            help="Tenant subdomain (e.g. test_tenant). Required unless --all is set.",
        )
        parser.add_argument(
            "--all",
            action="store_true",
            default=False,
            help="Run for all active tenants.",
        )
        parser.add_argument(
            "--no-input",
            action="store_true",
            help="Do not prompt for confirmation.",
        )

    def handle(self, *args, **options):
        if not options["tenant"] and not options["all"]:
            self.stderr.write(
                self.style.ERROR("Provide --tenant=SUBDOMAIN or --all.")
            )
            sys.exit(1)
        if options["tenant"] and options["all"]:
            self.stderr.write(
                self.style.ERROR("Use either --tenant=SUBDOMAIN or --all, not both.")
            )
            sys.exit(1)

        if options["tenant"]:
            tenants = list(
                Tenant.objects.using("default").filter(
                    subdomain__iexact=options["tenant"]
                )
            )
            if not tenants:
                self.stderr.write(
                    self.style.ERROR(f"Tenant '{options['tenant']}' not found.")
                )
                sys.exit(1)
        else:
            tenants = list(Tenant.objects.using("default").filter(is_active=True))
            if not tenants:
                self.stdout.write(self.style.WARNING("No active tenants."))
                return

        for tenant in tenants:
            self._clean_subscriptions_for_tenant(tenant, options["no_input"])

    def _clean_subscriptions_for_tenant(self, tenant, no_input):
        db_alias = f"tenant_{tenant.id}"
        if not tenant.db_name:
            self.stdout.write(
                self.style.WARNING(
                    f"  SKIP  {tenant.subdomain} — no db_name configured"
                )
            )
            return

        # Register tenant DB if needed
        default_db = settings.DATABASES["default"]
        if db_alias not in settings.DATABASES:
            db_config = copy.deepcopy(default_db)
            db_config.update({
                "NAME": tenant.db_name,
                "USER": tenant.db_user or default_db.get("USER", ""),
                "PASSWORD": tenant.db_password or default_db.get("PASSWORD", ""),
                "HOST": tenant.db_host or default_db.get("HOST", "localhost"),
                "PORT": tenant.db_port or default_db.get("PORT", "5432"),
                "ATOMIC_REQUESTS": False,
            })
            settings.DATABASES[db_alias] = db_config

        count = Subscription.objects.using(db_alias).count()
        if count == 0:
            self.stdout.write(
                self.style.SUCCESS(f"  {tenant.subdomain}: no subscriptions to delete.")
            )
            return

        if not no_input:
            confirm = input(
                f"  Delete {count} subscription(s) (and their orders, delivery statuses, etc.) "
                f"in tenant '{tenant.subdomain}'? [y/N]: "
            )
            if confirm.lower() != "y":
                self.stdout.write(f"  Skipped {tenant.subdomain}.")
                return

        # CASCADE removes: Order, SubscriptionEditRequest, DeliveryStatus (and DeliveryAssignment), etc.
        Subscription.objects.using(db_alias).all().delete()
        self.stdout.write(
            self.style.SUCCESS(f"  {tenant.subdomain}: deleted {count} subscription(s).")
        )
