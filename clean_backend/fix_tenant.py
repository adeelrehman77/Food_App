"""
Utility script to fix tenant DB config and reset admin user.
Usage: python fix_tenant.py <new_password>
"""
import os
import sys
import django
from django.conf import settings
from django.contrib.auth import get_user_model

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

from apps.users.models import Tenant


def fix_tenant_and_user():
    password = sys.argv[1] if len(sys.argv) > 1 else None
    if not password:
        print("Usage: python fix_tenant.py <new_admin_password>")
        print("ERROR: You must provide a password as a command-line argument.")
        sys.exit(1)

    try:
        # 1. Update Tenant to use default DB
        t = Tenant.objects.get(subdomain='test_kitchen')
        db_name = os.environ.get('DB_NAME', 'kitchen_production')
        db_user = os.environ.get('DB_USER', 'kitchen_user')
        print(f"Updating tenant '{t.name}' DB to '{db_name}'...")
        t.db_name = db_name
        t.db_user = db_user
        t.save()
        print("Tenant DB updated.")

        # 2. Reset admin password in default DB
        User = get_user_model()
        username = 'admin'
        try:
            u = User.objects.get(username=username)
            u.set_password(password)
            u.save()
            print(f"Password for '{username}' has been reset.")
        except User.DoesNotExist:
            print(f"User '{username}' not found. Creating...")
            User.objects.create_superuser(username, 'admin@test.com', password)
            print(f"User '{username}' created successfully.")

    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    fix_tenant_and_user()
