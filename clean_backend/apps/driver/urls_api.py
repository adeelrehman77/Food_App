from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.driver import views

app_name = 'driver_api'

router = DefaultRouter()
router.register(r'deliveries', views.DriverDeliveryViewSet, basename='delivery')

urlpatterns = [
    path('', views.api_index, name='api_index'),
    path('', include(router.urls)),
]
