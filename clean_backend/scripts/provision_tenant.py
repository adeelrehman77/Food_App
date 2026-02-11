import os
import sys
import django
import psycopg2
from psycopg2 import sql

# Setup Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from apps.users.models import Tenant
from django.core.management import call_command

def provision_tenant_db(tenant_id):
    """
    Physically creates a PostgreSQL database for a tenant and initializes schema.
    """
    tenant = Tenant.objects.get(id=tenant_id)
    
    # 1. Create the physical database using psycopg2 (connecting to 'postgres' db)
    # Note: Requires a superuser or user with CREATEDB privileges
    conn = psycopg2.connect(
        dbname='postgres',
        user=tenant.db_user,
        password=tenant.db_password,
        host=tenant.db_host,
        port=tenant.db_port
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    try:
        cur.execute(sql.Identifier(f"CREATE DATABASE {tenant.db_name}"))
        print(f"Successfully created database: {tenant.db_name}")
    except Exception as e:
        print(f"Error creating database: {e}")
    finally:
        cur.close()
        conn.close()

    # 2. Programmatically add the new DB to Django settings (for this process)
    from django.conf import settings
    db_alias = f"tenant_{tenant.id}"
    settings.DATABASES[db_alias] = {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': tenant.db_name,
        'USER': tenant.db_user,
        'PASSWORD': tenant.db_password,
        'HOST': tenant.db_host,
        'PORT': tenant.db_port,
    }

    # 3. Run migrations on the new database
    print(f"Running migrations for {db_alias}...")
    call_command('migrate', database=db_alias)

    # 4. Create default data (Admin User and Inventory Category)
    from django.contrib.auth.models import User
    from apps.main.models import Category
    
    print(f"Setting up default data for {tenant.name}...")
    if not User.objects.using(db_alias).filter(username='kitchen_admin').exists():
        admin = User.objects.create_user(
            username='kitchen_admin',
            email=f'admin@{tenant.subdomain}.com',
            password='default_password_123'
        )
        admin.is_staff = True
        admin.save(using=db_alias)
        print("- Created 'kitchen_admin' user.")
        
    Category.objects.using(db_alias).get_or_create(
        name='Inventory',
        defaults={'description': 'Default category for inventory items'}
    )
    print("- Created 'Inventory' category.")

    print(f"Tenant {tenant.name} provisioned successfully.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python provision_tenant.py <tenant_id>")
    else:
        provision_tenant_db(sys.argv[1])
