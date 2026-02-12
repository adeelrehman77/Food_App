from .base import *

# Development-specific settings
DEBUG = True

# Allow all hosts in development
ALLOWED_HOSTS = ['*']

# Development CORS settings
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = True # Deprecated but sometimes needed
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]
CORS_ORIGIN_REGEX_WHITELIST = [
    r"^https://\w+\.funadventure\.ae$",
    r"^http://localhost:[0-9]+$",
    r"^http://127\.0\.0\.1:[0-9]+$",
]

# Development uses base.py PostgreSQL config (DATABASE_URL or DB_* env vars)

# Development cache
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}

# Development email backend
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Development static files
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'

# Development logging
LOGGING['loggers']['django']['level'] = 'DEBUG'
LOGGING['loggers']['apps']['level'] = 'DEBUG'

# Development security settings
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
SECURE_HSTS_SECONDS = 0

# Development CSP (more permissive)
CSP_DEFAULT_SRC = ("'self'", "'unsafe-inline'", "'unsafe-eval'")
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://fonts.googleapis.com")
CSP_SCRIPT_SRC = ("'self'", "'unsafe-inline'", "'unsafe-eval'", "https://cdn.jsdelivr.net")
CSP_FONT_SRC = ("'self'", "https://fonts.gstatic.com")
CSP_IMG_SRC = ("'self'", "data:", "blob:")
CSP_CONNECT_SRC = ("'self'", "ws://localhost:*", "http://localhost:*")

# Disable axes in development
AXES_ENABLED = False

# Development API key (for testing)
SYNC_TOKEN = 'development_token_only_for_testing' 