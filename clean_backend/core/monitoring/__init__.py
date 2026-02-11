# Monitoring package
import time
import logging
from django.http import JsonResponse

logger = logging.getLogger(__name__)


class PrometheusMiddleware:
    """Prometheus metrics middleware for monitoring."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        start_time = time.time()
        
        # Process request
        response = self.get_response(request)
        
        # Calculate request time
        request_time = time.time() - start_time
        
        # Add Prometheus-style metrics headers
        response['X-Request-Duration'] = f"{request_time:.6f}"
        response['X-Request-Method'] = request.method
        response['X-Request-Path'] = request.path
        
        return response


__all__ = ['PrometheusMiddleware'] 