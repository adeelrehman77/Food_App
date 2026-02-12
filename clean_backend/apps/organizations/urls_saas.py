"""
SaaS Owner (Layer 1) API URLs.
Mounted at /api/saas/
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.organizations import views_saas as views

app_name = 'saas_api'

router = DefaultRouter()
router.register(r'tenants', views.TenantViewSet, basename='saas-tenant')
router.register(r'plans', views.ServicePlanViewSet, basename='saas-plan')
router.register(r'subscriptions', views.TenantSubscriptionViewSet, basename='saas-subscription')
router.register(r'invoices', views.TenantInvoiceViewSet, basename='saas-invoice')

urlpatterns = [
    path('analytics/', views.platform_analytics, name='saas-analytics'),
    path('', include(router.urls)),
]
