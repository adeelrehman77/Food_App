from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from core.db.router import set_current_db_alias, get_current_db_alias
from apps.users.models import Tenant
from apps.main.models import Category

@receiver(post_save, sender=Tenant)
def setup_tenant_defaults(sender, instance, created, **kwargs):
    if created:
        from django.conf import settings
        db_alias = f"tenant_{instance.id}"
        
        # We only attempt to setup defaults if the database connection exists.
        # Usually, this happens during the provisioning script, not the admin save.
        if db_alias not in settings.DATABASES:
            # We skip for now; the provision_tenant.py script will handle this.
            return
            
        old_alias = get_current_db_alias()
        try:
            set_current_db_alias(db_alias)
            # 1. Create 'Kitchen Admin' user
            if not User.objects.using(db_alias).filter(username='kitchen_admin').exists():
                admin = User.objects.create_user(
                    username='kitchen_admin',
                    email=f'admin@{instance.subdomain}.com',
                    password='default_password_123'
                )
                admin.is_staff = True
                admin.save(using=db_alias)
            
            # 2. Create default 'Inventory' category
            Category.objects.using(db_alias).get_or_create(
                name='Inventory',
                defaults={'description': 'Default category for inventory items'}
            )
        except Exception as e:
            # Prevent failures from blocking the Tenant creation in 'default' DB
            print(f"Error setting up tenant defaults for {db_alias}: {e}")
        finally:
            set_current_db_alias(old_alias)
