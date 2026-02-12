from django.db import models
from django.shortcuts import render
from django.http import JsonResponse
from rest_framework import viewsets, permissions, status as drf_status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.inventory.models import UnitOfMeasure, InventoryItem
from apps.inventory.serializers import (
    UnitOfMeasureSerializer, InventoryItemSerializer,
    InventoryStockUpdateSerializer,
)
from core.permissions.plan_limits import PlanFeatureInventory


def index(request):
    return render(request, 'inventory/index.html')


def api_index(request):
    return JsonResponse({'message': 'inventory API endpoint'})


class UnitOfMeasureViewSet(viewsets.ModelViewSet):
    """CRUD for units of measure (kg, litre, piece, etc.)."""
    queryset = UnitOfMeasure.objects.all()
    serializer_class = UnitOfMeasureSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['category']
    search_fields = ['name', 'abbreviation']


class InventoryItemViewSet(viewsets.ModelViewSet):
    """
    CRUD for inventory items.

    Extra actions:
    - ``POST /inventory-items/{id}/adjust_stock/`` — add or subtract stock
    - ``GET /inventory-items/low_stock/`` — list items below min_stock_level
    """
    queryset = InventoryItem.objects.select_related('unit').filter(is_active=True)
    serializer_class = InventoryItemSerializer
    permission_classes = [permissions.IsAuthenticated, PlanFeatureInventory]
    filterset_fields = ['is_active', 'unit']
    search_fields = ['name', 'supplier']
    ordering_fields = ['name', 'current_stock', 'updated_at']

    @action(detail=True, methods=['post'])
    def adjust_stock(self, request, pk=None):
        """Add or subtract stock. Positive = add, Negative = subtract."""
        item = self.get_object()
        serializer = InventoryStockUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        quantity = serializer.validated_data['quantity']
        new_stock = item.current_stock + quantity

        if new_stock < 0:
            return Response(
                {'error': 'Stock cannot go below zero.'},
                status=drf_status.HTTP_400_BAD_REQUEST,
            )

        item.current_stock = new_stock
        item.save(update_fields=['current_stock', 'updated_at'])
        return Response(InventoryItemSerializer(item).data)

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        """Return items where current_stock <= min_stock_level."""
        items = self.get_queryset().filter(
            current_stock__lte=models.F('min_stock_level'),
        )
        serializer = self.get_serializer(items, many=True)
        return Response(serializer.data)
