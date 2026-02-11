from .base import *

# Production-specific settings
DEBUG = False

# Production hosts
ALLOWED_HOSTS = [
    'kitchen.funadventure.ae',
    'www.kitchen.funadventure.ae',
    'api.kitchen.funadventure.ae',
]

# Production CORS settings
CORS_ALLOWED_ORIGINS = [
    "https://kitchen.funadventure.ae",
    "https://www.kitchen.funadventure.ae",
]
CORS_ALLOW_CREDENTIALS = True

# Production database (PostgreSQL required)
if not os.environ.get('DATABASE_URL'):
    raise ValueError("DATABASE_URL environment variable is required in production")

# Production cache (Redis)
if not os.environ.get('REDIS_URL'):
    raise ValueError("REDIS_URL environment variable is required in production")

# Production email backend
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = os.environ.get('EMAIL_HOST')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD')
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'no-reply@kitchen.funadventure.ae')

# Production static files
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Production logging
LOGGING['loggers']['django']['level'] = 'WARNING'
LOGGING['loggers']['apps']['level'] = 'INFO'

# Production security settings
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
X_FRAME_OPTIONS = 'DENY'

# Production CSP (strict)
CSP_DEFAULT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'", "https://cdn.jsdelivr.net", "https://fonts.googleapis.com")
CSP_SCRIPT_SRC = ("'self'", "https://cdn.jsdelivr.net")
CSP_FONT_SRC = ("'self'", "https://fonts.gstatic.com")
CSP_IMG_SRC = ("'self'", "data:", "https://storage.googleapis.com")
CSP_CONNECT_SRC = ("'self'",)
CSP_FRAME_ANCESTORS = ("'none'",)
CSP_FORM_ACTION = ("'self'",)
CSP_BLOCK_ALL_MIXED_CONTENT = True

# Enable axes in production
AXES_ENABLED = True

# Production API key (required)
if not os.environ.get('SYNC_TOKEN'):
    raise ValueError('SYNC_TOKEN environment variable is required in production')

# Enable Prometheus monitoring
ENABLE_PROMETHEUS = True

# Production rate limiting (stricter)
REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'] = {
    'anon': '50/hour',
    'user': '500/hour'
}

# Production session settings
SESSION_COOKIE_AGE = 1800  # 30 minutes
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default" 