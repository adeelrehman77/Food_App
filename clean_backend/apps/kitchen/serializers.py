"""
Kitchen app serializers for KDS (Kitchen Display System) APIs.
"""
from rest_framework import serializers
from apps.kitchen.models import KitchenOrder


class KitchenOrderSerializer(serializers.ModelSerializer):
    """Serializer for kitchen orders shown on the KDS."""
    order_id = serializers.IntegerField(source='order.id', read_only=True)
    order_status = serializers.CharField(source='order.status', read_only=True)
    customer_name = serializers.CharField(
        source='order.subscription.customer.user.get_full_name', read_only=True,
    )
    special_instructions = serializers.CharField(
        source='order.special_instructions', read_only=True,
    )
    assigned_to_name = serializers.CharField(
        source='assigned_to.get_full_name', read_only=True, default='',
    )

    class Meta:
        model = KitchenOrder
        fields = [
            'id', 'order_id', 'order_status',
            'customer_name', 'special_instructions',
            'assigned_to', 'assigned_to_name',
            'preparation_start_time', 'preparation_end_time',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
