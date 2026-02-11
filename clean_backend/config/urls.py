from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from rest_framework import permissions

# Swagger schema view
schema_view = get_schema_view(
    openapi.Info(
        title="Fun Adventure Kitchen API",
        default_version='v1',
        description="API for Fun Adventure Kitchen - Food delivery subscription management",
        terms_of_service="https://kitchen.funadventure.ae/terms/",
        contact=openapi.Contact(email="support@kitchen.funadventure.ae"),
        license=openapi.License(name="MIT License"),
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),
    
    # API Documentation
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    path('swagger.json', schema_view.without_ui(cache_timeout=0), name='schema-json'),
    
    # API v1
    path('api/v1/', include('apps.main.urls_api')),
    path('api/v1/kitchen/', include('apps.kitchen.urls_api')),
    path('api/v1/delivery/', include('apps.delivery.urls_api')),
    path('api/v1/inventory/', include('apps.inventory.urls_api')),
    path('api/v1/users/', include('apps.users.urls_api')),
    path('api/v1/driver/', include('apps.driver.urls_api')),
    
    # Authentication
    path('api/v1/auth/', include('dj_rest_auth.urls')),
    path('api/v1/auth/registration/', include('dj_rest_auth.registration.urls')),
    
    # Main app URLs
    path('', include('apps.main.urls')),
    path('kitchen/', include('apps.kitchen.urls')),
    path('driver/', include('apps.driver.urls')),
]

# Serve static and media files in development
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    
    # Debug toolbar
    import debug_toolbar
    urlpatterns += [
        path('__debug__/', include(debug_toolbar.urls)),
    ] 