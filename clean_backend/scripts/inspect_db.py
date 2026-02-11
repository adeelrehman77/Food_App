from django.db import connection

def inspect_table(table_name):
    with connection.cursor() as cursor:
        cursor.execute(f"SELECT column_name FROM information_schema.columns WHERE table_name = '{table_name}'")
        columns = [row[0] for row in cursor.fetchall()]
        print(f"Columns in {table_name}: {columns}")

if __name__ == "__main__":
    import django
    import os
    import sys
    sys.path.append(os.getcwd())
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
    django.setup()
    inspect_table('main_category')
    inspect_table('users_tenant')
