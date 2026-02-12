from django.shortcuts import render
from django.http import JsonResponse

from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from .models import Tenant
import json

def index(request):
    return render(request, 'users/index.html')

def api_index(request):
    return JsonResponse({
        'message': 'users API endpoint'
    })

@csrf_exempt
@require_POST
def discover_tenant(request):
    try:
        data = json.loads(request.body)
        kitchen_code = data.get('kitchen_code')
        
        if not kitchen_code:
            return JsonResponse({'error': 'Slug is required'}, status=400)
            
        # Try to find tenant by subdomain (slug)
        tenant = Tenant.objects.filter(subdomain__iexact=kitchen_code).first()
        
        if tenant:
            return JsonResponse({
                'api_endpoint': 'http://127.0.0.1:8000/api/v1/', 
                'tenant_id': tenant.subdomain,
                'name': tenant.name
            })
        else:
            return JsonResponse({'error': 'Tenant not found'}, status=404)
            
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
