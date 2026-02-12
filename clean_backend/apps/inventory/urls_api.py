from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'inventory_api'

router = DefaultRouter()
router.register(r'items', views.InventoryItemViewSet, basename='inventory-item')
router.register(r'units', views.UnitOfMeasureViewSet, basename='unit-of-measure')

urlpatterns = [
    path('', include(router.urls)),
]
