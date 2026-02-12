import os
import django
from django.conf import settings
from django.contrib.auth import get_user_model

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

from apps.users.models import Tenant

def create_tenant_user(slug, username, password, email):
    try:
        tenant = Tenant.objects.get(subdomain=slug)
    except Tenant.DoesNotExist:
        print(f"Tenant '{slug}' not found.")
        return

    # Dynamic DB configuration (mimicking middleware)
    db_alias = f"tenant_{tenant.id}"
    import copy
    db_config = copy.deepcopy(settings.DATABASES['default'])
    db_config.update({
        'NAME': tenant.db_name,
        # Use default credentials since tenant-specific role might not exist
        # 'USER': tenant.db_user,
        # 'PASSWORD': tenant.db_password,
        'HOST': tenant.db_host,
        'PORT': tenant.db_port,
    })
    settings.DATABASES[db_alias] = db_config

    User = get_user_model()
    
    # Check if user exists in tenant DB
    try:
        if User.objects.using(db_alias).filter(username=username).exists():
            print(f"User '{username}' already exists in tenant '{slug}' (DB: {tenant.db_name}).")
            u = User.objects.using(db_alias).get(username=username)
            u.set_password(password)
            u.is_superuser = True
            u.is_staff = True
            u.save(using=db_alias)
            print(f"Password reset for '{username}'.")
        else:
            print(f"Creating user '{username}' in tenant '{slug}' (DB: {tenant.db_name})...")
            User.objects.db_manager(db_alias).create_superuser(username, email, password)
            print(f"User '{username}' created successfully.")
            
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Error creating user: {e}")
        # Fallback for SQLite or if DB doesn't exist yet/migrations not run
        print("Check if the tenant database exists and migrations are applied.")

if __name__ == "__main__":
    create_tenant_user('test_kitchen', 'admin', 'admin123', 'admin@test.com')
