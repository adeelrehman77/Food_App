from django.conf import settings
from django.contrib.auth.models import User, Group
from django.db import transaction
from apps.driver.models import DeliveryDriver
from apps.users.models import Tenant
from core.db.router import set_current_db_alias
import copy

def register_tenant_db(tenant_subdomain):
    try:
        tenant = Tenant.objects.using('default').get(subdomain=tenant_subdomain)
    except Tenant.DoesNotExist:
        print(f"Tenant {tenant_subdomain} not found")
        return None

    db_alias = f"tenant_{tenant.id}"
    # Dynamically register the tenant's database
    if db_alias not in settings.DATABASES:
        db_config = copy.deepcopy(settings.DATABASES['default'])
        db_config.update({
            'NAME': tenant.db_name,
            'USER': tenant.db_user or db_config.get('USER', ''),
            'PASSWORD': tenant.db_password or db_config.get('PASSWORD', ''),
            'HOST': tenant.db_host or db_config.get('HOST', 'localhost'),
            'PORT': tenant.db_port or db_config.get('PORT', '5432'),
            'ATOMIC_REQUESTS': False,
        })
        settings.DATABASES[db_alias] = db_config
    return db_alias

def fix_drivers():
    tenant_subdomain = 'test_tenant' # Target tenant
    print(f"Starting driver linkage fix for {tenant_subdomain}...")
    
    db_alias = register_tenant_db(tenant_subdomain)
    if not db_alias:
        return

    # Set context so Router directs auth/driver calls to this DB
    set_current_db_alias(db_alias)
    print(f"Switched to database: {db_alias}")

    try:
        # Ensure Driver group exists in tenant DB
        driver_group, created = Group.objects.get_or_create(name='Driver')
        if created:
            print("Created 'Driver' group")

        drivers = DeliveryDriver.objects.filter(user__isnull=True)
        print(f"Found {drivers.count()} drivers without users")

        for driver in drivers:
            try:
                with transaction.atomic(): # Uses current DB alias by default due to router? 
                    # Actually ensure atomic block uses correct DB
                    # But since we set the alias, valid router should handle it.
                    
                    print(f"Processing driver: {driver.name} ({driver.phone})")
                    
                    # Check if user exists by username (phone)
                    username = driver.phone.replace('+', '').replace(' ', '')
                    email = driver.email or f"{username}@example.com"
                    
                    user = User.objects.filter(username=username).first()
                    if not user and driver.email:
                         user = User.objects.filter(email=driver.email).first()
                    
                    if not user:
                        print(f"Creating new user for {driver.name}")
                        user = User.objects.create_user(
                            username=username,
                            email=email,
                            password='temp_password_123',
                            first_name=driver.name.split()[0],
                            last_name=' '.join(driver.name.split()[1:]) if len(driver.name.split()) > 1 else '',
                            is_staff=True,
                            is_active=True
                        )
                    else:
                        print(f"Found existing user {user.username} for driver")
                        user.is_staff = True
                        user.save()
                    
                    # Add to group
                    user.groups.add(driver_group)
                    
                    # Link
                    driver.user = user
                    driver.save()
                    print(f"Successfully linked {driver.name} to user {user.username}")

            except Exception as e:
                print(f"Failed to process driver {driver.name}: {e}")
                import traceback
                traceback.print_exc()
                
    finally:
        set_current_db_alias('default')

fix_drivers()
