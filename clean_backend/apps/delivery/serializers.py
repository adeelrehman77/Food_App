"""
Delivery app serializers — for the Delivery model (order → delivery tracking).
"""
from rest_framework import serializers
from apps.delivery.models import Delivery


class DeliverySerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(
        source='driver.get_full_name', read_only=True, default='',
    )
    order_id = serializers.IntegerField(source='order.id', read_only=True)

    class Meta:
        model = Delivery
        fields = [
            'id', 'order', 'order_id', 'driver', 'driver_name',
            'pickup_time', 'delivery_time', 'status', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
