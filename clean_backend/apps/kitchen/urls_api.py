from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'kitchen_api'

router = DefaultRouter()
router.register(r'orders', views.KitchenOrderViewSet, basename='kitchen-order')

urlpatterns = [
    path('', include(router.urls)),
] 