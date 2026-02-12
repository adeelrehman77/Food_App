from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'delivery_api'

router = DefaultRouter()
router.register(r'deliveries', views.DeliveryViewSet, basename='delivery')

urlpatterns = [
    path('', include(router.urls)),
]
