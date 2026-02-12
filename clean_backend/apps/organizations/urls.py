from django.urls import path
from .views import TenantDiscoveryView

urlpatterns = [
    path('setup/discover/', TenantDiscoveryView.as_view(), name='tenant-discover'),
]
