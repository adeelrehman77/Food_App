from django.http import JsonResponse
from django.conf import settings
import logging
import re
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

class SecurityHeadersMiddleware:
    """Add security headers to all responses."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        response = self.get_response(request)
        
        # Basic security headers
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-Frame-Options'] = 'DENY'
        response['X-XSS-Protection'] = '1; mode=block'
        response['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        
        # Content Security Policy
        if not settings.DEBUG:
            csp_directives = [
                "default-src 'self'",
                "script-src 'self' https://cdn.jsdelivr.net https://unpkg.com",
                "style-src 'self' https://cdn.jsdelivr.net https://unpkg.com https://fonts.googleapis.com 'unsafe-inline'",
                "img-src 'self' data: https://cdn.jsdelivr.net https://storage.googleapis.com blob:",
                "font-src 'self' https://fonts.gstatic.com",
                "connect-src 'self' https://api.kitchen.funadventure.ae wss://api.kitchen.funadventure.ae",
                "media-src 'self'",
                "object-src 'none'",
                "frame-src 'self'",
                "base-uri 'self'",
                "form-action 'self'",
                "frame-ancestors 'none'",
                "upgrade-insecure-requests",
                "block-all-mixed-content"
            ]
            response['Content-Security-Policy'] = "; ".join(csp_directives)
        else:
            csp_directives = [
                "default-src 'self'",
                "script-src 'self' 'unsafe-eval' 'unsafe-inline' https://cdn.jsdelivr.net https://unpkg.com",
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://unpkg.com https://fonts.googleapis.com",
                "img-src 'self' data: blob:",
                "font-src 'self' https://fonts.gstatic.com",
                "connect-src 'self' ws://localhost:* http://localhost:*",
                "media-src 'self'",
                "object-src 'none'",
                "frame-ancestors 'none'"
            ]
            response['Content-Security-Policy'] = "; ".join(csp_directives)
            
        # Feature Policy
        feature_policy = [
            "geolocation 'self'",
            "midi 'none'",
            "sync-xhr 'self'",
            "microphone 'none'",
            "camera 'none'",
            "magnetometer 'none'",
            "gyroscope 'none'",
            "fullscreen 'self'",
            "payment 'none'"
        ]
        response['Permissions-Policy'] = "; ".join(feature_policy)
        
        return response


class ContentSecurityPolicyMiddleware:
    """Enhanced Content Security Policy middleware."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        response = self.get_response(request)
        
        # Add nonce to CSP for inline scripts
        if hasattr(request, 'csp_nonce'):
            csp_header = response.get('Content-Security-Policy', '')
            if csp_header and 'script-src' in csp_header:
                csp_header = csp_header.replace(
                    "script-src 'self'",
                    f"script-src 'self' 'nonce-{request.csp_nonce}'"
                )
                response['Content-Security-Policy'] = csp_header
        
        return response


class RequestValidationMiddleware:
    """Validate and sanitize incoming requests."""
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.max_request_size = 10 * 1024 * 1024  # 10MB
        
    def __call__(self, request):
        # Skip validation for static files and media
        if request.path.startswith(('/static/', '/media/')):
            return self.get_response(request)
            
        try:
            # Check request size
            content_length = request.META.get('CONTENT_LENGTH')
            if content_length and int(content_length) > self.max_request_size:
                return JsonResponse({
                    'error': 'Request too large'
                }, status=413)
                
            # Validate content type
            if request.method in ['POST', 'PUT', 'PATCH']:
                if not self._validate_content_type(request):
                    return JsonResponse({
                        'error': 'Invalid content type'
                    }, status=415)
                    
            # Sanitize request data
            if request.method in ['POST', 'PUT', 'PATCH']:
                if not self._sanitize_request_data(request):
                    return JsonResponse({
                        'error': 'Invalid request data'
                    }, status=400)
                    
            # Validate request headers
            if not self._validate_headers(request):
                return JsonResponse({
                    'error': 'Invalid request headers'
                }, status=400)
                
            # Validate URL parameters
            if not self._validate_url_params(request):
                return JsonResponse({
                    'error': 'Invalid URL parameters'
                }, status=400)
                
        except Exception as e:
            logger.error(f"Request validation error: {str(e)}")
            return JsonResponse({
                'error': 'Internal server error'
            }, status=500)
            
        return self.get_response(request)
        
    def _validate_content_type(self, request) -> bool:
        """Validate content type for POST/PUT/PATCH requests."""
        content_type = request.content_type.lower()
        allowed_types = [
            'application/json',
            'application/x-www-form-urlencoded',
            'multipart/form-data'
        ]
        return any(allowed_type in content_type for allowed_type in allowed_types)
        
    def _sanitize_request_data(self, request) -> bool:
        """Sanitize request data to prevent XSS and injection attacks."""
        try:
            import json
            
            # Sanitize JSON data
            if request.content_type and 'application/json' in request.content_type.lower():
                if request.body:
                    data = json.loads(request.body)
                    sanitized_data = self._sanitize_dict(data)
                    request._body = json.dumps(sanitized_data).encode()
                    
            # Sanitize form data
            elif request.POST:
                post_data = request.POST.copy()
                for key, value in post_data.items():
                    if isinstance(value, str):
                        post_data[key] = self._sanitize_string(value)
                request.POST = post_data
                        
            # Sanitize query parameters
            if request.GET:
                get_data = request.GET.copy()
                for key, value in get_data.items():
                    if isinstance(value, str):
                        get_data[key] = self._sanitize_string(value)
                request.GET = get_data
                        
            return True
            
        except Exception as e:
            logger.error(f"Error sanitizing request data: {str(e)}")
            return False
            
    def _sanitize_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively sanitize dictionary values."""
        if not isinstance(data, dict):
            return data
            
        sanitized = {}
        for key, value in data.items():
            if isinstance(value, str):
                sanitized[key] = self._sanitize_string(value)
            elif isinstance(value, dict):
                sanitized[key] = self._sanitize_dict(value)
            elif isinstance(value, list):
                sanitized[key] = [self._sanitize_dict(item) if isinstance(item, dict) 
                                else self._sanitize_string(item) if isinstance(item, str)
                                else item for item in value]
            else:
                sanitized[key] = value
        return sanitized
        
    def _sanitize_string(self, value: str) -> str:
        """Sanitize string to prevent XSS and injection attacks."""
        # Remove script tags
        value = re.sub(r'<script[^>]*>.*?</script>', '', value, flags=re.IGNORECASE | re.DOTALL)
        
        # Remove other potentially dangerous tags
        value = re.sub(r'<(iframe|object|embed)[^>]*>.*?</\1>', '', value, flags=re.IGNORECASE | re.DOTALL)
        
        # Remove javascript: protocol
        value = re.sub(r'javascript:', '', value, flags=re.IGNORECASE)
        
        # Remove on* event handlers
        value = re.sub(r'on\w+\s*=', '', value, flags=re.IGNORECASE)
        
        return value
        
    def _validate_headers(self, request) -> bool:
        """Validate request headers."""
        # Check for required headers
        required_headers = ['HTTP_USER_AGENT']
        for header in required_headers:
            if header not in request.META:
                return False
        return True
        
    def _validate_url_params(self, request) -> bool:
        """Validate URL parameters."""
        # Check for suspicious patterns in URL parameters
        suspicious_patterns = [
            r'<script',
            r'javascript:',
            r'data:text/html',
            r'vbscript:',
            r'onload=',
            r'onerror=',
        ]
        
        for pattern in suspicious_patterns:
            if re.search(pattern, request.get_full_path(), re.IGNORECASE):
                return False
        return True


class InputValidationMiddleware:
    """Validate input data for malicious content."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Validate GET parameters
        for key, value in request.GET.items():
            if self._contains_xss(value):
                return JsonResponse({
                    'error': 'Invalid input detected'
                }, status=400)
        
        # Validate POST parameters
        for key, value in request.POST.items():
            if self._contains_xss(value):
                return JsonResponse({
                    'error': 'Invalid input detected'
                }, status=400)
        
        return self.get_response(request)
    
    def _contains_xss(self, value):
        """Check if value contains XSS patterns."""
        if not isinstance(value, str):
            return False
        
        xss_patterns = [
            r'<script[^>]*>',
            r'javascript:',
            r'vbscript:',
            r'on\w+\s*=',
            r'<iframe[^>]*>',
            r'<object[^>]*>',
            r'<embed[^>]*>',
        ]
        
        for pattern in xss_patterns:
            if re.search(pattern, value, re.IGNORECASE):
                return True
        return False 