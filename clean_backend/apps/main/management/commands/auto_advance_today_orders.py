"""
Advance today's orders through the kitchen flow and push to Delivery Management.

For each tenant: orders with delivery_date = today are moved:
  pending → confirmed → preparing → ready
and a Delivery record is created for each order that becomes ready (so they appear
in Delivery Management for driver assignment).

Run daily via cron (e.g. at 10:00) so all of today's subscription orders are
ready and in the delivery queue without manual clicking.

Usage:
    python manage.py auto_advance_today_orders --tenant=test_tenant
    python manage.py auto_advance_today_orders --all
    python manage.py auto_advance_today_orders --all --no-input  # no confirmation
"""
import copy
import sys

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.main.models import Order
from apps.users.models import Tenant


class Command(BaseCommand):
    help = (
        "Advance today's orders through pending→confirmed→preparing→ready "
        "and create Delivery records so they appear in Delivery Management."
    )

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

        today = timezone.now().date()
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
            self._advance_for_tenant(tenant, today, options["no_input"])

    def _advance_for_tenant(self, tenant, today, no_input):
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

        order_qs = Order.objects.using(db_alias).filter(
            delivery_date=today,
            status__in=('pending', 'confirmed', 'preparing'),
        )
        count = order_qs.count()
        if count == 0:
            self.stdout.write(
                self.style.SUCCESS(
                    f"  {tenant.subdomain}: no orders to advance for {today}."
                )
            )
            return

        if not no_input:
            confirm = input(
                f"  Advance {count} order(s) for {today} in tenant '{tenant.subdomain}' "
                f"to ready and create Deliveries? [y/N]: "
            )
            if confirm.lower() != "y":
                self.stdout.write(f"  Skipped {tenant.subdomain}.")
                return

        # Advance in steps so we don't skip a step
        Order.objects.using(db_alias).filter(
            delivery_date=today, status='pending',
        ).update(status='confirmed')
        Order.objects.using(db_alias).filter(
            delivery_date=today, status='confirmed',
        ).update(status='preparing')
        ready_ids = list(
            Order.objects.using(db_alias).filter(
                delivery_date=today, status='preparing',
            ).values_list('id', flat=True)
        )
        Order.objects.using(db_alias).filter(id__in=ready_ids).update(status='ready')

        # Create Delivery for each order that is now ready (so they appear in Delivery Management)
        from apps.delivery.models import Delivery
        created_deliveries = 0
        for order_id in ready_ids:
            # get_or_create needs the order instance; we only have id
            order = Order.objects.using(db_alias).get(id=order_id)
            _, created = Delivery.objects.using(db_alias).get_or_create(
                order=order,
                defaults={'status': 'pending'},
            )
            if created:
                created_deliveries += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"  {tenant.subdomain}: advanced {count} order(s) to ready, "
                f"created {created_deliveries} delivery record(s)."
            )
        )
