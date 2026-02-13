import os
from pathlib import Path
import logging
from datetime import timedelta
import dj_database_url
import sys
import dotenv

# Load environment variables from .env file
dotenv.load_dotenv()

logger = logging.getLogger(__name__)

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Environment variable handling
from django.core.management.utils import get_random_secret_key

# Get environment variables with defaults
DJANGO_ENV = os.environ.get('DJANGO_ENV', 'development')
IS_TESTING = 'pytest' in sys.modules
DEBUG = DJANGO_ENV != 'production' or IS_TESTING

SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')
if not SECRET_KEY:
    if DEBUG:
        # Stable development key — avoids invalidating JWT tokens on every restart.
        # NEVER use this in production. Set DJANGO_SECRET_KEY env var instead.
        SECRET_KEY = 'django-insecure-dev-key-do-not-use-in-production-xk9!q2'
    else:
        raise ValueError("SECRET_KEY environment variable is required in production")

# Host configuration
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '').split(',') if os.environ.get('ALLOWED_HOSTS') else []
if DEBUG:
    ALLOWED_HOSTS = ['*']
PORT = int(os.environ.get('PORT', 8000))

# CSRF settings
CSRF_TRUSTED_ORIGINS = os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(',') if os.environ.get('CSRF_TRUSTED_ORIGINS') else []
if DEBUG:
    CSRF_TRUSTED_ORIGINS += ['http://localhost:8000', 'http://127.0.0.1:8000', 'http://0.0.0.0:8000']

# CORS Settings
CORS_ALLOW_ALL_ORIGINS = DEBUG  # Only allow all origins in development
CORS_ALLOW_CREDENTIALS = True

CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
    'x-api-key',
    'x-tenant-slug',
]

CORS_EXPOSE_HEADERS = [
    'x-ratelimit-limit',
    'x-ratelimit-remaining',
    'x-ratelimit-reset',
]

# Rate Limiting Settings
DEFAULT_RATE_LIMIT = 100  # requests per minute
AUTH_RATE_LIMIT = 5      # requests per minute for auth endpoints
API_RATE_LIMIT = 100  # 100 requests per window
API_RATE_LIMIT_WINDOW = 60  # 60 seconds window
API_KEY_EXPIRY_DAYS = 90  # API keys expire after 90 days

# Logging Configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'security': {
            'format': '{levelname} {asctime} {message}',
            'style': '{',
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse',
        },
        'require_debug_true': {
            '()': 'django.utils.log.RequireDebugTrue',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': os.path.join(BASE_DIR, 'logs', 'django.log'),
            'formatter': 'verbose',
        },
        'security_file': {
            'level': 'WARNING',
            'class': 'logging.FileHandler',
            'filename': os.path.join(BASE_DIR, 'logs', 'security.log'),
            'formatter': 'security',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
        'apps': {
            'handlers': ['file', 'console', 'security_file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}

# Cache Configuration
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
} if DEBUG else {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'PARSER_CLASS': 'redis.connection.HiredisParser',
            'SOCKET_CONNECT_TIMEOUT': 5,
            'SOCKET_TIMEOUT': 5,
            'RETRY_ON_TIMEOUT': True,
            'MAX_CONNECTIONS': 1000,
            'CONNECTION_POOL_CLASS': 'redis.connection.BlockingConnectionPool',
            'CONNECTION_POOL_CLASS_KWARGS': {
                'max_connections': 50,
                'timeout': 20,
            }
        }
    }
}

# Cache timeout in seconds (5 minutes)
CACHE_MIDDLEWARE_SECONDS = 300

# Add SITE_ID for django-allauth
SITE_ID = 1

# Application definition
INSTALLED_APPS = [
    'channels',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'import_export',
    'rest_framework',
    'rest_framework.authtoken',
    'django.contrib.sites',
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'dj_rest_auth',
    'dj_rest_auth.registration',
    'django_user_agents',
    'axes',
    'csp',
    'drf_yasg',
    'django_filters',

    # Local apps
    'apps.users',
    'apps.organizations',
    'apps.main',
    'apps.kitchen',
    'apps.delivery',
    'apps.inventory',
    'apps.driver',
]

DATABASE_ROUTERS = (
    'core.db.router.TenantRouter',
)

# APScheduler configuration
_db_user = os.environ.get('DB_USER', 'postgres')
_db_pass = os.environ.get('DB_PASSWORD', '')
_db_host = os.environ.get('DB_HOST', 'localhost')
_db_port = os.environ.get('DB_PORT', '5432')
_db_name = os.environ.get('DB_NAME', 'food_app')
_db_cred = f"{_db_user}:{_db_pass}@" if _db_pass else f"{_db_user}@"
_scheduler_db_url = os.environ.get(
    'DATABASE_URL',
    f'postgresql://{_db_cred}{_db_host}:{_db_port}/{_db_name}',
)

SCHEDULER_CONFIG = {
    'apscheduler.jobstores.default': {
        'type': 'sqlalchemy',
        'url': _scheduler_db_url,
    },
    'apscheduler.executors.default': {
        'class': 'apscheduler.executors.pool:ThreadPoolExecutor',
        'max_workers': '20',
    },
    'apscheduler.job_defaults.coalesce': 'true',
    'apscheduler.job_defaults.max_instances': '3',
    'apscheduler.job_defaults.replace_existing': 'true',
}
SCHEDULER_AUTOSTART = True
APSCHEDULER_RUN_NOW = True
DELIVERY_AUTO_COMPLETE = True
PAYMENT_AUTO_PROCESS = True

# REST Framework Configuration
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10,
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle'
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour'
    },
    'DEFAULT_VERSIONING_CLASS': 'rest_framework.versioning.URLPathVersioning',
    'DEFAULT_VERSION': 'v1',
    'ALLOWED_VERSIONS': ['v1'],
    'VERSION_PARAM': 'version'
}

# JWT Configuration
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,
    'VERIFYING_KEY': None,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
    'TOKEN_TYPE_CLAIM': 'token_type',
}

# REST Auth Configuration
REST_AUTH = {
    'USE_JWT': True,
    'JWT_AUTH_COOKIE': 'auth',
    'JWT_AUTH_REFRESH_COOKIE': 'refresh-auth',
    'JWT_AUTH_HTTPONLY': True,
    'USER_DETAILS_SERIALIZER': 'apps.users.serializers.UserDetailsSerializer',
    'PASSWORD_RESET_USE_SITES_DOMAIN': True,
    'OLD_PASSWORD_FIELD_ENABLED': True,
}

# Middleware Configuration
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'core.middleware.multi_db_tenant.MultiDbTenantMiddleware', # Custom multi-db isolation
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    # NOTE: Per-site cache middleware removed — it caches ALL GET responses
    # (including API JSON) for CACHE_MIDDLEWARE_SECONDS, which breaks SPA/API
    # workflows. Use @cache_page on specific views when caching is needed.
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'allauth.account.middleware.AccountMiddleware',  # Required from allauth >=0.56.0
    'apps.users.middleware.SecurityMiddleware',
    'apps.users.middleware.SessionTimeoutMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'core.middleware.SecurityHeadersMiddleware',
    'core.middleware.ContentSecurityPolicyMiddleware',
    'csp.middleware.CSPMiddleware',
    'django_user_agents.middleware.UserAgentMiddleware',
    'axes.middleware.AxesMiddleware',
    'core.middleware.JSONResponseMiddleware',
    'core.middleware.RateLimitMiddleware',
    'core.middleware.PerformanceMonitoringMiddleware',
    'core.middleware.QueryOptimizationMiddleware',
    'core.middleware.MonitoringMiddleware',
    'core.middleware.RequestLoggingMiddleware',
    'core.middleware.ExceptionMiddleware',
    'core.middleware.RequestValidationMiddleware',
    'core.middleware.APIMetricsMiddleware',
    # 'debug_toolbar.middleware.DebugToolbarMiddleware',
    'apps.kitchen.middleware.APIRequestValidationMiddleware',
]

# Add Prometheus middleware in production
if not DEBUG and os.environ.get('ENABLE_PROMETHEUS', 'False').lower() == 'true':
    MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
    MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')
    MIDDLEWARE.append('core.monitoring.PrometheusMiddleware')
    INSTALLED_APPS.append('django_prometheus')

# Session settings
SESSION_COOKIE_AGE = 1800  # 30 minutes in seconds
SESSION_SAVE_EVERY_REQUEST = True
SESSION_EXPIRE_AT_BROWSER_CLOSE = True

# Use cache session engine in production, db in development
if not DEBUG:
    SESSION_ENGINE = "django.contrib.sessions.backends.cache"
    SESSION_CACHE_ALIAS = "default"
else:
    SESSION_ENGINE = "django.contrib.sessions.backends.db"

# Security settings
if not DEBUG:  # In production
    SECURE_SSL_REDIRECT = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    CSRF_COOKIE_HTTPONLY = True
    CSRF_COOKIE_SAMESITE = 'Lax'
    SESSION_COOKIE_SAMESITE = 'Lax'
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    X_FRAME_OPTIONS = 'DENY'
    
    # Production CORS — read from env or use defaults
    CORS_ALLOWED_ORIGINS = (
        os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',')
        if os.environ.get('CORS_ALLOWED_ORIGINS')
        else [
            "https://kitchen.funadventure.ae",
            "https://www.kitchen.funadventure.ae",
        ]
    )
else:  # In development
    SECURE_SSL_REDIRECT = False
    SECURE_PROXY_SSL_HEADER = None
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False
    CSRF_COOKIE_HTTPONLY = False
    CSRF_COOKIE_SAMESITE = 'Lax'
    SESSION_COOKIE_SAMESITE = 'Lax'
    X_FRAME_OPTIONS = 'SAMEORIGIN'
    SECURE_HSTS_SECONDS = 0
    SECURE_HSTS_INCLUDE_SUBDOMAINS = False
    SECURE_HSTS_PRELOAD = False

    # Development CORS — CORS_ALLOW_ALL_ORIGINS=True handles this,
    # but explicit list is still needed for credentialed requests.
    CORS_ALLOWED_ORIGINS = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
    ]

# Content Security Policy settings
CSP_DEFAULT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net", "https://fonts.googleapis.com")
CSP_SCRIPT_SRC = ("'self'", "'unsafe-inline'", "'unsafe-eval'", "https://cdn.jsdelivr.net")
CSP_FONT_SRC = ("'self'", "https://fonts.gstatic.com")
CSP_IMG_SRC = ("'self'", "data:", "https://storage.googleapis.com")
CSP_CONNECT_SRC = ("'self'",)
CSP_FRAME_ANCESTORS = ("'none'",)
CSP_FORM_ACTION = ("'self'",)
CSP_INCLUDE_NONCE_IN = ('script-src',)
CSP_BLOCK_ALL_MIXED_CONTENT = True

# Django-axes settings for security
AXES_FAILURE_LIMIT = 5
AXES_LOCK_OUT_AT_FAILURE = True
AXES_COOLOFF_TIME = 1  # Lock out for 1 hour
AXES_RESET_ON_SUCCESS = True
AXES_LOCKOUT_TEMPLATE = 'account_locked.html'
AXES_LOCKOUT_URL = '/accounts/locked/'
AXES_ENABLED = not DEBUG  # Disabled in development, enabled in production

# Authentication backends
AUTHENTICATION_BACKENDS = [
    'axes.backends.AxesStandaloneBackend',
    'django.contrib.auth.backends.ModelBackend',
    'allauth.account.auth_backends.AuthenticationBackend',
]

CSRF_USE_SESSIONS = False
CSRF_COOKIE_NAME = 'csrftoken'

CONN_MAX_AGE = 60
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024

# Root URL configuration
ROOT_URLCONF = 'config.urls'

# Templates configuration
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# WSGI application
WSGI_APPLICATION = 'config.wsgi.application'

# ASGI application
ASGI_APPLICATION = 'config.asgi.application'

# Channels configuration
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    }
}

# Use Redis channel layer in production if available
if not DEBUG and os.environ.get('REDIS_URL'):
    redis_host = os.environ.get('REDIS_HOST', 'localhost')
    redis_port = int(os.environ.get('REDIS_PORT', 6379))
    
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels_redis.core.RedisChannelLayer',
            'CONFIG': {
                'hosts': [(redis_host, redis_port)],
                'capacity': 1500,
                'expiry': 60,
            },
        },
    }

# Database configuration — PostgreSQL
if os.environ.get('DATABASE_URL'):
    DATABASES = {
        'default': dj_database_url.config(
            default=os.environ.get('DATABASE_URL'),
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('DB_NAME', 'food_app'),
            'USER': os.environ.get('DB_USER', 'postgres'),
            'PASSWORD': os.environ.get('DB_PASSWORD', ''),
            'HOST': os.environ.get('DB_HOST', 'localhost'),
            'PORT': os.environ.get('DB_PORT', '5432'),
            'CONN_MAX_AGE': 600,
        }
    }

# Enable query logging in development
if DEBUG:
    for db_config in DATABASES.values():
        db_config['OPTIONS'] = db_config.get('OPTIONS', {})
        # Use Django's built-in query logging instead of database-level debug
        if 'debug' in db_config['OPTIONS']:
            del db_config['OPTIONS']['debug']
    
    # Enable Django's query logging
    LOGGING['loggers']['django.db.backends'] = {
        'handlers': ['console'],
        'level': 'DEBUG',
        'propagate': False,
    }

# Enable atomic requests for all database operations
DATABASES['default']['ATOMIC_REQUESTS'] = True

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# WhatsApp API Configuration
WHATSAPP_PHONE_ID = os.environ.get('WHATSAPP_PHONE_ID', '')
WHATSAPP_TOKEN = os.environ.get('WHATSAPP_TOKEN', '')

# Custom error handlers
handler404 = 'apps.main.views.handler404'
handler500 = 'apps.main.views.handler500'

# Login/Logout URLs
LOGIN_REDIRECT_URL = '/'
LOGIN_URL = '/login/'
KITCHEN_LOGIN_URL = '/kitchen/login/'
KITCHEN_LOGIN_REDIRECT_URL = '/kitchen/dashboard/'
LOGOUT_REDIRECT_URL = '/'

# Email configuration
if DEBUG:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
else:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = os.environ.get('EMAIL_HOST', '')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
    EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
    EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
    EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
    DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'no-reply@kitchen.funadventure.ae')
    ADMINS = [('Admin', email) for email in os.environ.get('ADMIN_EMAILS', '').split(',') if email]

# Security token
SYNC_TOKEN = os.getenv('SYNC_TOKEN')
if not SYNC_TOKEN:
    if DEBUG:
        SYNC_TOKEN = 'development_token_only_for_testing'
        logger.warning("Using development SYNC_TOKEN. Set SYNC_TOKEN environment variable in production.")
    else:
        raise ValueError('SYNC_TOKEN environment variable is required in production')

# Whitenoise configuration for static files in production
if not DEBUG:
    # STORAGES replaces the deprecated STATICFILES_STORAGE in Django 4.2+
    STORAGES = {
        'default': {
            'BACKEND': 'django.core.files.storage.FileSystemStorage',
        },
        'staticfiles': {
            'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage',
        },
    }
    WHITENOISE_MAX_AGE = 604800  # 1 week in seconds

# Debug toolbar configuration
if DEBUG:
    INTERNAL_IPS = ['127.0.0.1']
    if os.environ.get('DOCKER_HOST_IP'):
        INTERNAL_IPS.append(os.environ.get('DOCKER_HOST_IP'))
    try:
        import socket
        _, _, ips = socket.gethostbyname_ex(socket.gethostname())
        INTERNAL_IPS += [ip[: ip.rfind(".")] + ".1" for ip in ips]
    except socket.gaierror:
        pass  # DNS resolution failed — use defaults

# DRF-YASG settings
SWAGGER_SETTINGS = {
    'SECURITY_DEFINITIONS': {
        'Bearer': {
            'type': 'apiKey',
            'name': 'Authorization',
            'in': 'header'
        }
    },
    'USE_SESSION_AUTH': False,
    'JSON_EDITOR': True,
    'SUPPORTED_SUBMIT_METHODS': [
        'get',
        'post',
        'put',
        'delete',
        'patch'
    ],
}

# Cache middleware settings (kept for reference if per-site cache is re-enabled)
# CACHE_MIDDLEWARE_ALIAS = 'default'
# CACHE_MIDDLEWARE_KEY_PREFIX = 'kitchen'

# Email verification settings
ACCOUNT_EMAIL_VERIFICATION = 'none'
ACCOUNT_AUTHENTICATION_METHOD = 'username_email'
ACCOUNT_EMAIL_REQUIRED = True
ACCOUNT_UNIQUE_EMAIL = True
ACCOUNT_USERNAME_REQUIRED = True
ACCOUNT_USER_MODEL_USERNAME_FIELD = 'username'
ACCOUNT_LOGIN_ON_EMAIL_CONFIRMATION = True

# Encryption Settings
ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY')
if not ENCRYPTION_KEY:
    if DEBUG:
        # Stable dev key so encrypted data survives restarts during development.
        # NEVER use this in production.
        ENCRYPTION_KEY = 'dev-only-not-secure-aaaaaaaaaaaaaaaa'
        logger.warning("Using development ENCRYPTION_KEY. Set ENCRYPTION_KEY env var in production.")
    else:
        from cryptography.fernet import Fernet
        raise ValueError(
            "ENCRYPTION_KEY environment variable is required in production. "
            f"Generate one with: python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
        )