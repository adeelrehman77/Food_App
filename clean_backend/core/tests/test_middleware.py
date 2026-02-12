import pytest
from django.test import RequestFactory, override_settings
from django.http import HttpResponse
from core.middleware.performance import PerformanceMonitoringMiddleware
from core.middleware.security import SecurityHeadersMiddleware

def get_response(request):
    return HttpResponse("OK")

class TestMiddleware:
    def test_performance_middleware(self):
        middleware = PerformanceMonitoringMiddleware(get_response)
        factory = RequestFactory()
        request = factory.get('/')
        response = middleware(request)
        assert response.status_code == 200
        assert 'X-Request-Time' in response.headers

    def test_monitoring_middleware(self):
        from core.middleware.performance import MonitoringMiddleware
        middleware = MonitoringMiddleware(get_response)
        factory = RequestFactory()
        request = factory.get('/')
        response = middleware(request)
        assert response.status_code == 200
        assert 'X-Response-Time' in response.headers

    def test_security_middleware(self):
        middleware = SecurityHeadersMiddleware(get_response)
        factory = RequestFactory()
        request = factory.get('/')
        response = middleware(request)
        assert response.status_code == 200
        assert response['X-Content-Type-Options'] == 'nosniff'
        assert response['X-Frame-Options'] == 'DENY'
