import os
import django
from django.conf import settings
from django.contrib.auth import get_user_model

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

from apps.users.models import Tenant

def fix_tenant_and_user():
    try:
        # 1. Update Tenant to use default DB
        t = Tenant.objects.get(subdomain='test_kitchen')
        print(f"Updating tenant '{t.name}' from DB '{t.db_name}' to 'kitchen_production'...")
        t.db_name = 'kitchen_production'
        t.db_user = 'kitchen_user' # Reset to default if needed, or keep as is if ignored
        t.save()
        print("Tenant DB updated.")

        # 2. Reset admin password in default DB
        User = get_user_model()
        username = 'admin'
        try:
            u = User.objects.get(username=username)
            u.set_password('admin123')
            u.save()
            print(f"Password for '{username}' reset to 'admin123'.")
        except User.DoesNotExist:
            print(f"User '{username}' not found. Creating...")
            User.objects.create_superuser(username, 'admin@test.com', 'admin123')
            print(f"User '{username}' created with password 'admin123'.")
            
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Error: {e}")

if __name__ == "__main__":
    fix_tenant_and_user()
