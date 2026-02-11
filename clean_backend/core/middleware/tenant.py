import threading
from django.conf import settings
from apps.users.models import Tenant

# Thread-local storage for the current tenant
_thread_locals = threading.local()

def get_current_tenant():
    """Get the current tenant from thread-local storage."""
    return getattr(_thread_locals, 'tenant', None)

def set_current_tenant(tenant):
    """Set the current tenant in thread-local storage."""
    _thread_locals.tenant = tenant

class TenantSubdomainMiddleware:
    """
    Middleware to identify the tenant based on the subdomain of the incoming request.
    Example: kitchen1.funadventure.ae -> Tenant with name/subdomain 'kitchen1'
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        host = request.get_host().split(':')[0]  # Remove port if exists
        domain_parts = host.split('.')
        
        # Logic to extract subdomain:
        # If hosting on funadventure.ae, then <subdomain>.funadventure.ae has 3+ parts
        if len(domain_parts) >= 3:
            subdomain = domain_parts[0]
            
            try:
                # Find the tenant. Note: 'name' is used here, but you might want 
                # to add a specific 'subdomain' field to the Tenant model.
                tenant = Tenant.objects.get(name__iexact=subdomain)
                set_current_tenant(tenant)
                request.tenant = tenant
            except Tenant.DoesNotExist:
                # Handle case where subdomain is invalid
                set_current_tenant(None)
                request.tenant = None
        else:
            # No subdomain (e.g., funadventure.ae)
            set_current_tenant(None)
            request.tenant = None

        response = self.get_response(request)
        
        # Clear thread-local after request to prevent leak
        set_current_tenant(None)
        return response
