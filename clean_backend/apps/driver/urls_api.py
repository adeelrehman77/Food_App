from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.driver import views

app_name = 'driver_api'

router = DefaultRouter()

# Driver-facing endpoints
router.register(r'deliveries', views.DriverDeliveryViewSet, basename='delivery')

# Admin-facing delivery management endpoints
router.register(r'zones', views.ZoneViewSet, basename='zone')
router.register(r'routes', views.RouteViewSet, basename='route')
router.register(r'drivers', views.DeliveryDriverViewSet, basename='driver')
router.register(r'schedules', views.DeliveryScheduleViewSet, basename='schedule')
router.register(r'assignments', views.DeliveryAssignmentAdminViewSet, basename='assignment')

urlpatterns = [
    path('', include(router.urls)),
]
