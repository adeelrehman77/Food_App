from rest_framework import serializers
from apps.driver.models import DeliveryAssignment, DeliveryStatus
from apps.main.serializers.customer_serializers import AddressSerializer

class DeliveryStatusSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='subscription.customer.user.get_full_name', read_only=True)
    customer_phone = serializers.CharField(source='subscription.customer.phone', read_only=True)
    subscription_details = serializers.SerializerMethodField()
    delivery_address = AddressSerializer(read_only=True)

    def get_subscription_details(self, obj):
        return ", ".join([menu.name for menu in obj.subscription.menus.all()])

    class Meta:
        model = DeliveryStatus
        fields = [
            'id', 'status', 'date', 'delivery_time', 'actual_delivery_time',
            'customer_name', 'customer_phone', 'subscription_details',
            'delivery_address', 'driver_notes', 'customer_notes',
            'payment_processed', 'payment_amount'
        ]
        read_only_fields = ['status', 'actual_delivery_time', 'payment_processed']

class DeliveryAssignmentSerializer(serializers.ModelSerializer):
    delivery_details = DeliveryStatusSerializer(source='delivery_status', read_only=True)

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'delivery_status', 'delivery_details',
            'estimated_pickup_time', 'estimated_delivery_time', 'notes'
        ]
