import os
import sys
import django
from django.db import connection

# Setup Django
sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
django.setup()

def fix_migrations():
    functional_apps = ['delivery', 'driver', 'inventory', 'kitchen', 'main']
    
    with connection.cursor() as cursor:
        print(f"Clearing migration records for: {functional_apps} from default DB")
        cursor.execute("DELETE FROM django_migrations WHERE app IN %s", [tuple(functional_apps)])
        print("Records cleared.")

if __name__ == "__main__":
    fix_migrations()
