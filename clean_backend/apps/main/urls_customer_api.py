"""
Customer-facing API URLs (Layer 3: B2C).
Mounted at /api/v1/customer/
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.main.views import customer_api_views as views

app_name = 'customer_api'

router = DefaultRouter()
router.register(r'subscriptions', views.CustomerSubscriptionViewSet, basename='customer-subscription')
router.register(r'orders', views.CustomerOrderViewSet, basename='customer-order')
router.register(r'wallet', views.CustomerWalletViewSet, basename='customer-wallet')
router.register(r'invoices', views.CustomerInvoiceViewSet, basename='customer-invoice')
router.register(r'notifications', views.CustomerNotificationViewSet, basename='customer-notification')
router.register(r'addresses', views.CustomerAddressViewSet, basename='customer-address')

urlpatterns = [
    # Auth (no token required)
    path('auth/register/', views.customer_register, name='customer-register'),
    path('auth/login/', views.customer_login, name='customer-login'),

    # Public menu (no token required)
    path('menu/', views.public_menu, name='public-menu'),
    path('menu/categories/', views.public_categories, name='public-categories'),

    # Profile (token required)
    path('profile/', views.CustomerProfileView.as_view(), name='customer-profile'),

    # Router-based endpoints (token required)
    path('', include(router.urls)),
]
