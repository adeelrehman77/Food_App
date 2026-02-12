from .base import *

# Test-specific settings
DEBUG = False

# Test database — PostgreSQL (same as base, use test DB name via env or default)
import os
_db_name = os.environ.get('DB_NAME', 'food_app')
_test_db = os.environ.get('TEST_DB_NAME', f'{_db_name}_test')
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': _test_db,
        'USER': os.environ.get('DB_USER', 'postgres'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
        'CONN_MAX_AGE': 0,
    }
}

# Test cache
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'test-cache',
    }
}

# Test email backend
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

# Test static files
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'

# Test logging
LOGGING['loggers']['django']['level'] = 'ERROR'
LOGGING['loggers']['apps']['level'] = 'ERROR'

# Disable security features for testing
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
SECURE_HSTS_SECONDS = 0

# Disable axes for testing
AXES_ENABLED = False

# Test API key
SYNC_TOKEN = 'test_token'

# Disable Prometheus for testing
ENABLE_PROMETHEUS = False

# Test rate limiting (very permissive)
REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'] = {
    'anon': '1000/hour',
    'user': '10000/hour'
}

# Test session settings
SESSION_COOKIE_AGE = 3600  # 1 hour for tests
SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_ENGINE = "django.contrib.sessions.backends.db" 