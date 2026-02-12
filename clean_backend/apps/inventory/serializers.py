"""
Inventory app serializers.
"""
from rest_framework import serializers
from apps.inventory.models import UnitOfMeasure, InventoryItem


class UnitOfMeasureSerializer(serializers.ModelSerializer):
    class Meta:
        model = UnitOfMeasure
        fields = ['id', 'name', 'abbreviation', 'category', 'conversion_factor', 'created_at']
        read_only_fields = ['created_at']


class InventoryItemSerializer(serializers.ModelSerializer):
    unit_name = serializers.CharField(source='unit.name', read_only=True)
    unit_abbreviation = serializers.CharField(source='unit.abbreviation', read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)

    class Meta:
        model = InventoryItem
        fields = [
            'id', 'name', 'description', 'unit', 'unit_name', 'unit_abbreviation',
            'current_stock', 'min_stock_level', 'cost_per_unit', 'supplier',
            'is_active', 'is_low_stock', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class InventoryStockUpdateSerializer(serializers.Serializer):
    """For adjusting stock (add or subtract)."""
    quantity = serializers.DecimalField(max_digits=10, decimal_places=2)
    reason = serializers.CharField(required=False, allow_blank=True, default='')
