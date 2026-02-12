from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.main import views

app_name = 'main_api'

router = DefaultRouter()

# Tenant-admin endpoints
router.register(r'menu-items', views.MenuItemViewSet, basename='menu-item')
router.register(r'categories', views.CategoryViewSet, basename='category')
router.register(r'orders', views.OrderViewSet, basename='order')
router.register(r'customers', views.CustomerProfileViewSet, basename='customer')
router.register(r'registration-requests', views.CustomerRegistrationRequestViewSet, basename='registration-request')
router.register(r'invoices', views.InvoiceViewSet, basename='invoice')
router.register(r'notifications', views.NotificationViewSet, basename='notification')
router.register(r'staff', views.StaffUserViewSet, basename='staff')

# Customer-facing endpoints (read-only for now)
router.register(r'subscriptions', views.SubscriptionViewSet, basename='subscription')
router.register(r'wallet', views.WalletTransactionViewSet, basename='wallet-transaction')
router.register(r'addresses', views.AddressViewSet, basename='address')

urlpatterns = [
    path('health/', views.health_check, name='health_check'),
    path('', include(router.urls)),
]