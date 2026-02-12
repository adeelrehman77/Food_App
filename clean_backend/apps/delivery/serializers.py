"""
Delivery app serializers — for the Delivery model (order → delivery tracking).
"""
from rest_framework import serializers
from apps.delivery.models import Delivery


class DeliverySerializer(serializers.ModelSerializer):
    driver_name = serializers.SerializerMethodField()
    order_id = serializers.IntegerField(source='order.id', read_only=True)
    customer_name = serializers.SerializerMethodField()
    delivery_address = serializers.SerializerMethodField()

    class Meta:
        model = Delivery
        fields = [
            'id', 'order', 'order_id', 'driver', 'driver_name',
            # 'customer_name', 
            'delivery_address',
            'pickup_time', 'delivery_time', 'status', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def get_driver_name(self, obj):
        if obj.driver:
            name = obj.driver.get_full_name()
            return name if name.strip() else obj.driver.username
        return ''

    def get_customer_name(self, obj):
        if hasattr(obj.order, 'subscription') and obj.order.subscription:
            customer = obj.order.subscription.customer
            if hasattr(customer, 'user'):
                name = customer.user.get_full_name()
                return name if name.strip() else customer.user.username
        return ''

    def get_delivery_address(self, obj):
        if hasattr(obj.order, 'subscription') and obj.order.subscription:
            sub = obj.order.subscription
            addr = getattr(sub, 'lunch_address', None) or getattr(sub, 'dinner_address', None)
            if addr:
                return str(addr)
        return ''
