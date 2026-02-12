"""
Seed default MealSlot records on the specified database(s).

Usage:
    python manage.py seed_meal_slots                  # default DB only
    python manage.py seed_meal_slots --all-tenants    # all tenant DBs + default
"""
import copy
import datetime

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.main.models import MealSlot


DEFAULT_SLOTS = [
    {
        'name': 'Lunch',
        'code': 'lunch',
        'cutoff_time': datetime.time(10, 0),
        'sort_order': 1,
    },
    {
        'name': 'Dinner',
        'code': 'dinner',
        'cutoff_time': datetime.time(16, 0),
        'sort_order': 2,
    },
]


class Command(BaseCommand):
    help = 'Seed default MealSlot records (Lunch, Dinner).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--all-tenants',
            action='store_true',
            default=False,
            help='Seed on all tenant databases in addition to default.',
        )

    def handle(self, *args, **options):
        # Always seed default
        self._seed('default')

        if options['all_tenants']:
            self._seed_all_tenants()

    def _seed_all_tenants(self):
        from apps.users.models import Tenant

        tenants = Tenant.objects.filter(is_active=True)
        default_db = settings.DATABASES['default']

        for tenant in tenants:
            if not tenant.db_name:
                self.stdout.write(
                    self.style.WARNING(f"  SKIP {tenant.subdomain} — no db_name")
                )
                continue

            db_alias = f"tenant_{tenant.id}"
            if db_alias not in settings.DATABASES:
                db_config = copy.deepcopy(default_db)
                db_config.update({
                    'NAME': tenant.db_name,
                    'USER': tenant.db_user or default_db.get('USER', ''),
                    'PASSWORD': tenant.db_password or default_db.get('PASSWORD', ''),
                    'HOST': tenant.db_host or default_db.get('HOST', 'localhost'),
                    'PORT': tenant.db_port or default_db.get('PORT', '5432'),
                    'ATOMIC_REQUESTS': False,
                })
                settings.DATABASES[db_alias] = db_config

            self.stdout.write(f"\n  Seeding tenant: {tenant.subdomain} ({tenant.db_name})")
            self._seed(db_alias)

    def _seed(self, alias):
        for slot_data in DEFAULT_SLOTS:
            obj, created = MealSlot.objects.using(alias).get_or_create(
                code=slot_data['code'],
                defaults=slot_data,
            )
            verb = 'Created' if created else 'Exists'
            self.stdout.write(f"  [{alias}] {verb}: {obj.name} (code={obj.code})")

        self.stdout.write(self.style.SUCCESS(f"  [{alias}] MealSlot seeding complete."))
