import copy
import logging

from django.conf import settings
from django.http import HttpResponseForbidden, JsonResponse
from apps.users.models import Tenant
from core.db.router import set_current_db_alias

logger = logging.getLogger(__name__)


class MultiDbTenantMiddleware:
    """
    Middleware to identify the tenant and select the appropriate database.

    Identification order:
      1. ``X-Tenant-ID`` or ``X-Tenant-Slug`` header
      2. Subdomain extracted from the ``Host`` header

    After resolving the tenant, the middleware:
      - Dynamically registers the tenant database in ``settings.DATABASES``
      - Sets the thread-local DB alias so the ``TenantRouter`` uses it
      - Attaches ``request.tenant`` (Tenant instance or None)
      - Attaches ``request.tenant_plan`` (ServicePlan instance or None)
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tenant_id = (
            request.headers.get('X-Tenant-ID')
            or request.headers.get('X-Tenant-Slug')
        )

        # Fallback to subdomain
        if not tenant_id:
            host = request.get_host().split(':')[0]
            is_ip = host.replace('.', '').isnumeric()
            if not is_ip and host != 'localhost':
                parts = host.split('.')
                if len(parts) >= 3:
                    tenant_id = parts[0]

        if tenant_id:
            try:
                tenant = Tenant.objects.using('default').select_related(
                    'service_plan',
                ).get(subdomain__iexact=tenant_id, is_active=True)
            except Tenant.DoesNotExist:
                return JsonResponse(
                    {'error': 'Invalid or inactive tenant.'},
                    status=403,
                )

            db_alias = f"tenant_{tenant.id}"

            # Dynamically register the tenant's database if not already present
            if db_alias not in settings.DATABASES:
                db_config = copy.deepcopy(settings.DATABASES['default'])
                db_config.update({
                    'NAME': tenant.db_name or f"kitchen_tenant_{tenant.subdomain}",
                    'USER': tenant.db_user or db_config.get('USER', ''),
                    'PASSWORD': tenant.db_password or db_config.get('PASSWORD', ''),
                    'HOST': tenant.db_host or db_config.get('HOST', 'localhost'),
                    'PORT': tenant.db_port or db_config.get('PORT', '5432'),
                    # Do NOT set ATOMIC_REQUESTS — it causes Django to open
                    # connections to ALL registered DBs for every request,
                    # even when the router routes queries to 'default'.
                    'ATOMIC_REQUESTS': False,
                    'CONN_MAX_AGE': 600,
                })
                settings.DATABASES[db_alias] = db_config

            set_current_db_alias(db_alias)
            request.tenant = tenant
            request.tenant_plan = tenant.service_plan  # may be None
        else:
            set_current_db_alias('default')
            request.tenant = None
            request.tenant_plan = None

        response = self.get_response(request)

        # Reset after request
        set_current_db_alias('default')
        return response
