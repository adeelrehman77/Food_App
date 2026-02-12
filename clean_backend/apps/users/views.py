from django.shortcuts import render
from django.http import JsonResponse

from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from .models import Tenant
import json
import logging

logger = logging.getLogger(__name__)


def _build_api_endpoint(request):
    """Build the API endpoint URL dynamically from the incoming request."""
    scheme = 'https' if request.is_secure() else 'http'
    host = request.get_host()
    return f'{scheme}://{host}/api/v1/'


def index(request):
    return render(request, 'users/index.html')


def api_index(request):
    return JsonResponse({
        'message': 'users API endpoint',
        'version': 'v1',
    })


@csrf_exempt
@require_POST
def discover_tenant(request):
    try:
        data = json.loads(request.body)
        kitchen_code = data.get('kitchen_code')

        if not kitchen_code:
            return JsonResponse({'error': 'Kitchen code is required'}, status=400)

        tenant = Tenant.objects.filter(subdomain__iexact=kitchen_code).first()

        if not tenant:
            return JsonResponse({'error': 'Kitchen not found'}, status=404)

        if not tenant.is_active:
            return JsonResponse({'error': 'This kitchen is currently inactive'}, status=403)

        return JsonResponse({
            'api_endpoint': _build_api_endpoint(request),
            'tenant_id': tenant.subdomain,
            'name': tenant.name,
        })

    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        logger.exception('Error in discover_tenant')
        return JsonResponse({'error': 'An unexpected error occurred'}, status=500)
