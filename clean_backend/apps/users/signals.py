import os
import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from django.utils.crypto import get_random_string
from core.db.router import set_current_db_alias, get_current_db_alias
from apps.users.models import Tenant
from apps.main.models import Category

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Tenant)
def setup_tenant_defaults(sender, instance, created, **kwargs):
    """
    When a new Tenant is created, seed its dedicated database with
    a default admin user and a default category.

    The router sends ``auth.User`` and ``main.Category`` to whichever
    DB alias is set in thread-local storage — so we temporarily switch
    to the tenant's alias and all ORM operations go to the right place.
    """
    if not created:
        return

    from django.conf import settings

    db_alias = f"tenant_{instance.id}"

    # Only proceed if the tenant DB connection is already registered
    # (it is during provisioning, but not during a plain admin save).
    if db_alias not in settings.DATABASES:
        return

    old_alias = get_current_db_alias()
    try:
        set_current_db_alias(db_alias)

        # 1. Create 'Kitchen Admin' user (lives in the tenant DB)
        if not User.objects.filter(username='kitchen_admin').exists():
            default_password = os.environ.get(
                'DEFAULT_TENANT_ADMIN_PASSWORD',
                get_random_string(length=24),
            )
            admin = User.objects.create_user(
                username='kitchen_admin',
                email=f'admin@{instance.subdomain}.com',
                password=default_password,
            )
            admin.is_staff = True
            admin.save()
            logger.info(
                "Created kitchen_admin for tenant '%s' in DB '%s'. "
                "Password was set from DEFAULT_TENANT_ADMIN_PASSWORD env var "
                "or generated randomly.",
                instance.subdomain,
                db_alias,
            )

        # 2. Create default 'Inventory' category (lives in the tenant DB)
        Category.objects.get_or_create(
            name='Inventory',
            defaults={'description': 'Default category for inventory items'},
        )

    except Exception as e:
        logger.error("Error setting up tenant defaults for %s: %s", db_alias, e)
    finally:
        set_current_db_alias(old_alias)
