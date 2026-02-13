import os
import sys
import django
from django.db import connection

# Setup Django
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

def get_local_apps():
    return ['users', 'organizations', 'main', 'kitchen', 'delivery', 'inventory', 'driver']

def reset_schema():
    apps = get_local_apps()
    
    with connection.cursor() as cursor:
        # 1. Clear django_migrations for these apps
        print(f"Clearing migrations for: {apps}")
        cursor.execute("DELETE FROM django_migrations WHERE app IN %s", [tuple(apps)])
        
        # 2. Identify and drop tables for these apps
        # We look for tables starting with the app labels
        cursor.execute(r"""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND (
                table_name LIKE 'users\_%' OR 
                table_name LIKE 'organizations\_%' OR 
                table_name LIKE 'main\_%' OR 
                table_name LIKE 'kitchen\_%' OR 
                table_name LIKE 'delivery\_%' OR 
                table_name LIKE 'inventory\_%' OR 
                table_name LIKE 'driver\_%'
            )
        """)
        tables = [row[0] for row in cursor.fetchall()]
        
        print(f"Dropping tables: {tables}")
        for table in tables:
            try:
                cursor.execute(f"DROP TABLE IF EXISTS \"{table}\" CASCADE")
                print(f"- Dropped {table}")
            except Exception as e:
                print(f"- Error dropping {table}: {e}")

if __name__ == "__main__":
    confirm = input("This will DELETE ALL DATA in local apps (Tenants, Customers, etc.). Continue? (y/n): ")
    if confirm.lower() == 'y':
        reset_schema()
        print("Schema reset complete. Now run 'python manage.py migrate'")
    else:
        print("Aborted.")
