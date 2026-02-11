from django.conf import settings
from django.db import connections
from django.http import HttpResponseForbidden
from apps.users.models import Tenant
from core.db.router import set_current_db_alias

class MultiDbTenantMiddleware:
    """
    Middleware to identify the tenant and select the appropriate database.
    Identifies via X-Tenant-ID header or subdomain.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tenant_id = request.headers.get('X-Tenant-ID')
        
        # Fallback to subdomain if header is missing
        if not tenant_id:
            host = request.get_host().split(':')[0]
            domain_parts = host.split('.')
            if len(domain_parts) >= 3:
                tenant_id = domain_parts[0]

        if tenant_id:
            try:
                # Always look up the tenant in the 'default' database
                tenant = Tenant.objects.using('default').get(
                    subdomain__iexact=tenant_id, 
                    is_active=True
                )
                
                db_alias = f"tenant_{tenant.id}"
                
                # Check if this database configuration exists in Django settings
                # If not, we might need to add it dynamically (advanced)
                if db_alias not in settings.DATABASES:
                    settings.DATABASES[db_alias] = {
                        'ENGINE': 'django.db.backends.postgresql',
                        'NAME': tenant.db_name,
                        'USER': tenant.db_user,
                        'PASSWORD': tenant.db_password,
                        'HOST': tenant.db_host,
                        'PORT': tenant.db_port,
                    }
                
                set_current_db_alias(db_alias)
                request.tenant = tenant
                
            except Tenant.DoesNotExist:
                return HttpResponseForbidden("Invalid or inactive tenant.")
        else:
            # Shared/Admin area or no tenant identified
            set_current_db_alias('default')
            request.tenant = None

        response = self.get_response(request)
        
        # Reset after request
        set_current_db_alias('default')
        return response
