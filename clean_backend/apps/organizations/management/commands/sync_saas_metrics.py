from django.core.management.base import BaseCommand
from django.conf import settings
from django.db import connections
from django.utils import timezone
from django.db.models import Sum
import copy

from apps.users.models import Tenant, UserProfile
from apps.organizations.models_saas import TenantUsage

# Import models from other apps (these schemas exist in tenant DBs)
from apps.main.models import Order, CustomerProfile, MenuItem, Subscription


class Command(BaseCommand):
    help = 'Calculates and syncs SaaS metrics (MRR, ARR, usage) for all active tenants.'

    def handle(self, *args, **options):
        self.stdout.write("Starting SaaS metrics sync...")
        
        # 1. Fetch all active tenants from the default database
        tenants = Tenant.objects.using('default').filter(is_active=True)
        
        total_tenants = tenants.count()
        self.stdout.write(f"Found {total_tenants} active tenants.")

        current_date = timezone.now().date()
        # Calculate start of current month for filtering (if needed)
        start_of_month = current_date.replace(day=1)

        for tenant in tenants:
            self.stdout.write(f"Processing tenant: {tenant.name} ({tenant.subdomain})...")
            
            # 2. Configure Dynamic Database Connection
            db_alias = f"tenant_{tenant.id}"
            
            # Construct DB Name: use defined db_name or fallback pattern
            db_name = tenant.db_name or f"kitchen_tenant_{tenant.subdomain}"
            
            if db_alias not in settings.DATABASES:
                default_db = settings.DATABASES['default']
                db_config = copy.deepcopy(default_db)
                db_config.update({
                    'NAME': db_name,
                    'USER': tenant.db_user or default_db.get('USER', ''),
                    'PASSWORD': tenant.db_password or default_db.get('PASSWORD', ''),
                    'HOST': tenant.db_host or default_db.get('HOST', 'localhost'),
                    'PORT': tenant.db_port or default_db.get('PORT', '5432'),
                    'ATOMIC_REQUESTS': False, # Avoid transaction overhead for metrics
                })
                settings.DATABASES[db_alias] = db_config

            try:
                # Ensure connection works before querying
                connections[db_alias].ensure_connection()
                
                # 3. Calculate Metrics (Querying the TENANT DB)
                
                # Order Count (All time or monthly? Requirement implies general usage, let's do all-time for now per model definitions, 
                # but TenantUsage has a 'period' field which implies monthly. 
                # Let's pivot to MONTHLY metrics based on TenantUsage.period field docstring "First day of the month")
                
                # Orders created this month
                order_count = Order.objects.using(db_alias).filter(
                    created_at__date__gte=start_of_month
                ).count()
                
                # Customer Count (Total active profiles)
                customer_count = CustomerProfile.objects.using(db_alias).count()
                
                # Staff Count (Staff profiles)
                staff_count = UserProfile.objects.using(db_alias).count() 
                # Note: UserProfile in Tenant DB usually links to tenant staff. 
                # Since User is shared in some architectures but here seems replicated or separate auth_user per DB
                # per TenantRouter docstring: "Each tenant database has its own auth_user table".
                
                # Menu Item Count (Total items)
                menu_item_count = MenuItem.objects.using(db_alias).count()
                
                # Subscription Count (Active subscriptions)
                subscription_count = Subscription.objects.using(db_alias).filter(
                    status='active'
                ).count()
                
                # Revenue (Sum of total_cost of subscriptions active/created this month or just total active MRR?)
                # Simplest view of "Revenue" for usage stats often means GMV (Gross Merchandise Value) or Subscription Revenue.
                # Let's calculate Total Cost of Subscriptions active in this month.
                revenue_agg = Subscription.objects.using(db_alias).filter(
                    # Consider subscriptions active in this period
                    status__in=['active', 'completed', 'expired'], # Include expired if it was active this month? 
                    # Let's stick to created or active overlap.
                    # For simplicity and robustness given "Usage" context:
                    # Sum of 'total_cost' of all subscriptions that are 'active' currently.
                    status='active'
                ).aggregate(total=Sum('total_cost'))
                
                revenue = revenue_agg['total'] or 0

                # 4. Save metrics to Shared/Default DB
                # TenantUsage is in the 'default' DB (apps.organizations are SAAS_ONLY_APPS)
                
                usage_record, created = TenantUsage.objects.using('default').update_or_create(
                    tenant=tenant,
                    period=start_of_month,
                    defaults={
                        'order_count': order_count,
                        'customer_count': customer_count,
                        'staff_count': staff_count,
                        'menu_item_count': menu_item_count,
                        'subscription_count': subscription_count,
                        'revenue': revenue,
                    }
                )
                
                action = "Created" if created else "Updated"
                self.stdout.write(self.style.SUCCESS(f"  -> {action} usage record for {start_of_month}."))

            except Exception as e:
                self.stdout.write(self.style.ERROR(f"  -> Failed to sync tenant '{tenant.name}': {e}"))
                # Clean up connection if possible
                if db_alias in settings.DATABASES:
                    del settings.DATABASES[db_alias]

        self.stdout.write(self.style.SUCCESS("SaaS metrics sync completed."))
