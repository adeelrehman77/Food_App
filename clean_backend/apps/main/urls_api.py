from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.main import views

app_name = 'main_api'

router = DefaultRouter()
router.register(r'subscriptions', views.SubscriptionViewSet, basename='subscription')
router.register(r'wallet', views.WalletTransactionViewSet, basename='wallet-transaction')
router.register(r'addresses', views.AddressViewSet, basename='address')

urlpatterns = [
    path('health/', views.health_check, name='health_check'),
    path('', include(router.urls)),
]