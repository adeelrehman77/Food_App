from django.http import JsonResponse
from django.db import connection
import time
import logging
import psutil
from django.conf import settings

logger = logging.getLogger(__name__)

class PerformanceMonitoringMiddleware:
    """Monitor performance metrics for requests."""
    
    SLOW_QUERY_TIME = 0.5  # seconds
    HIGH_QUERY_COUNT = 50
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Start timing
        start_time = time.time()
        
        # Get initial query count (with error handling)
        try:
            initial_queries = len(connection.queries) if hasattr(connection, 'queries') else 0
        except (AttributeError, TypeError):
            initial_queries = 0
        
        # Get initial memory usage
        try:
            initial_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        except (AttributeError, OSError):
            initial_memory = 0
        
        # Process request
        response = self.get_response(request)
        
        # Calculate metrics
        request_time = time.time() - start_time
        
        try:
            query_count = len(connection.queries) - initial_queries if hasattr(connection, 'queries') else 0
        except (AttributeError, TypeError):
            query_count = 0
        
        try:
            memory_used = (psutil.Process().memory_info().rss / 1024 / 1024) - initial_memory
        except (AttributeError, OSError):
            memory_used = 0
        
        # Log slow requests
        if request_time > self.SLOW_QUERY_TIME:
            logger.warning(
                f"Slow request: {request.path} took {request_time:.2f}s "
                f"({query_count} queries, {memory_used:.2f}MB memory)"
            )
        
        # Log high query count
        if query_count > self.HIGH_QUERY_COUNT:
            logger.warning(
                f"High query count: {request.path} executed {query_count} queries "
                f"in {request_time:.2f}s"
            )
        
        # Add performance headers
        response['X-Request-Time'] = f"{request_time:.3f}"
        response['X-Query-Count'] = str(query_count)
        response['X-Memory-Used'] = f"{memory_used:.2f}"
        
        return response
    
    def process_view(self, request, view_func, view_args, view_kwargs):
        # Track view function execution
        start_time = time.time()
        
        # Store start time for later use
        request._view_start_time = start_time
        
        return None
    
    def process_template_response(self, request, response):
        # Calculate view execution time
        if hasattr(request, '_view_start_time'):
            view_time = time.time() - request._view_start_time
            response['X-View-Time'] = f"{view_time:.3f}"
        
        return response


class QueryOptimizationMiddleware:
    """Monitor and optimize database queries."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Clear query log at start (with error handling)
        try:
            if hasattr(connection, 'queries_log'):
                connection.queries_log = []
        except (AttributeError, TypeError):
            pass
        
        # Process request
        response = self.get_response(request)
        
        # Analyze queries in development
        if settings.DEBUG:
            self._analyze_queries(request)
        
        return response
    
    def _analyze_queries(self, request):
        """Analyze database queries for optimization opportunities."""
        try:
            queries = connection.queries if hasattr(connection, 'queries') else []
        except (AttributeError, TypeError):
            queries = []
        
        if not queries:
            return
        
        # Check for N+1 queries
        query_patterns = {}
        for query in queries:
            sql = query.get('sql', '').lower()
            if 'select' in sql and 'from' in sql:
                # Extract table name (simplified)
                parts = sql.split('from')
                if len(parts) > 1:
                    table = parts[1].split()[0].strip()
                    query_patterns[table] = query_patterns.get(table, 0) + 1
        
        # Log potential N+1 queries
        for table, count in query_patterns.items():
            if count > 5:  # Threshold for N+1 detection
                logger.warning(
                    f"Potential N+1 query detected: {count} queries on {table} "
                    f"for request {request.path}"
                )
        
        # Log duplicate queries
        sql_queries = [q.get('sql', '') for q in queries]
        duplicate_queries = [sql for sql in set(sql_queries) if sql_queries.count(sql) > 1]
        
        if duplicate_queries:
            logger.warning(
                f"Duplicate queries detected in {request.path}: "
                f"{len(duplicate_queries)} unique queries executed multiple times"
            )


class RateLimitMiddleware:
    """Rate limiting middleware."""
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.rate_limit = {}
        self.rate_limit_window = 60  # 1 minute
        self.max_requests = 100  # requests per minute
    
    def __call__(self, request):
        client_ip = self._get_client_ip(request)
        current_time = time.time()
        
        # Clean up old entries
        self.rate_limit = {ip: data for ip, data in self.rate_limit.items() 
                          if current_time - data['timestamp'] < self.rate_limit_window}
        
        # Check rate limit
        if client_ip in self.rate_limit:
            if self.rate_limit[client_ip]['count'] >= self.max_requests:
                return JsonResponse({
                    'error': 'Rate limit exceeded',
                    'retry_after': int(self.rate_limit_window - (current_time - self.rate_limit[client_ip]['timestamp']))
                }, status=429)
            self.rate_limit[client_ip]['count'] += 1
        else:
            self.rate_limit[client_ip] = {
                'count': 1,
                'timestamp': current_time
            }
        
        return self.get_response(request)
    
    def _get_client_ip(self, request):
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            return x_forwarded_for.split(',')[0]
        return request.META.get('REMOTE_ADDR')


class APIMetricsMiddleware:
    """Collect API metrics for monitoring."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Only track API requests
        if not request.path.startswith('/api/'):
            return self.get_response(request)
        
        start_time = time.time()
        
        # Process request
        response = self.get_response(request)
        
        # Calculate metrics
        request_time = time.time() - start_time
        
        # Log API metrics
        logger.info(
            f"API Request: {request.method} {request.path} "
            f"- Status: {response.status_code} "
            f"- Time: {request_time:.3f}s "
            f"- IP: {self._get_client_ip(request)}"
        )
        
        # Add metrics headers
        response['X-API-Version'] = 'v1'
        response['X-Request-ID'] = self._generate_request_id()
        
        return response
    
    def _get_client_ip(self, request):
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            return x_forwarded_for.split(',')[0]
        return request.META.get('REMOTE_ADDR')
    
    def _generate_request_id(self):
        """Generate a unique request ID."""
        import uuid
        return str(uuid.uuid4())[:8]


class JSONResponseMiddleware:
    """Ensure consistent JSON responses for API endpoints."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        response = self.get_response(request)
        
        # Add JSON response headers for API requests
        if request.path.startswith('/api/'):
            response['Content-Type'] = 'application/json'
        
        return response


class MonitoringMiddleware:
    """General monitoring middleware for application health."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        start_time = time.time()
        
        # Process request
        response = self.get_response(request)
        
        # Calculate request time
        request_time = time.time() - start_time
        
        # Add monitoring headers
        response['X-Response-Time'] = f"{request_time:.3f}"
        response['X-Server-Time'] = time.strftime('%Y-%m-%d %H:%M:%S')
        
        return response


class RequestLoggingMiddleware:
    """Log all incoming requests for debugging and monitoring."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Log request start
        logger.info(f"Request started: {request.method} {request.path}")
        
        # Process request
        response = self.get_response(request)
        
        # Log request completion
        logger.info(f"Request completed: {request.method} {request.path} - Status: {response.status_code}")
        
        return response


class ExceptionMiddleware:
    """Handle exceptions and provide consistent error responses."""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        try:
            response = self.get_response(request)
            return response
        except Exception as e:
            logger.error(f"Unhandled exception in {request.path}: {str(e)}")
            
            # Return JSON error response for API requests
            if request.path.startswith('/api/'):
                return JsonResponse({
                    'error': 'Internal server error',
                    'message': 'An unexpected error occurred'
                }, status=500)
            
            # Re-raise for non-API requests to let Django handle it
            raise 