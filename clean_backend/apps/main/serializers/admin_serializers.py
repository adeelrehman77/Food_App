"""
Serializers for tenant-admin facing APIs.
These are used by kitchen staff, managers, and tenant admins.
"""
from rest_framework import serializers
from django.contrib.auth.models import User

from apps.main.models import (
    Order, Subscription, CustomerProfile, Invoice, InvoiceItem,
    Notification, CustomerRegistrationRequest, Category,
)


# ─── Orders ────────────────────────────────────────────────────────────────────

class OrderListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for order lists."""
    customer_name = serializers.CharField(
        source='subscription.customer.user.get_full_name', read_only=True,
    )
    customer_phone = serializers.CharField(
        source='subscription.customer.phone', read_only=True,
    )

    class Meta:
        model = Order
        fields = [
            'id', 'subscription', 'order_date', 'delivery_date',
            'status', 'quantity', 'special_instructions',
            'customer_name', 'customer_phone',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class OrderDetailSerializer(serializers.ModelSerializer):
    """Full serializer with nested subscription info."""
    customer_name = serializers.CharField(
        source='subscription.customer.user.get_full_name', read_only=True,
    )
    customer_phone = serializers.CharField(
        source='subscription.customer.phone', read_only=True,
    )
    subscription_id = serializers.IntegerField(source='subscription.id', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'subscription', 'subscription_id',
            'order_date', 'delivery_date', 'status',
            'quantity', 'special_instructions',
            'customer_name', 'customer_phone',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at', 'subscription']


class OrderStatusUpdateSerializer(serializers.Serializer):
    """For updating order status only."""
    status = serializers.ChoiceField(choices=Order.STATUS_CHOICES)
    reason = serializers.CharField(required=False, allow_blank=True)


# ─── Customers (admin view) ───────────────────────────────────────────────────

class CustomerProfileAdminSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    full_name = serializers.CharField(source='user.get_full_name', read_only=True)

    class Meta:
        model = CustomerProfile
        fields = [
            'id', 'username', 'email', 'full_name',
            'name', 'phone', 'emirates_id', 'zone',
            'wallet_balance', 'loyalty_points', 'loyalty_tier',
            'preferred_communication', 'created_at', 'updated_at',
        ]
        read_only_fields = ['wallet_balance', 'loyalty_points', 'created_at', 'updated_at']


class CustomerRegistrationRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomerRegistrationRequest
        fields = [
            'id', 'name', 'contact_number', 'address',
            'meal_selection', 'meal_type', 'quantity',
            'status', 'admin_notes', 'rejection_reason',
            'created_at', 'processed_at',
        ]
        read_only_fields = ['created_at', 'processed_at']


# ─── Invoices ──────────────────────────────────────────────────────────────────

class InvoiceItemSerializer(serializers.ModelSerializer):
    menu_name = serializers.CharField(source='menu.name', read_only=True)

    class Meta:
        model = InvoiceItem
        fields = ['id', 'menu', 'menu_name', 'quantity', 'unit_price', 'total_price']


class InvoiceSerializer(serializers.ModelSerializer):
    items = InvoiceItemSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(
        source='customer.user.get_full_name', read_only=True,
    )

    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'customer', 'customer_name',
            'date', 'due_date', 'total', 'status', 'notes',
            'items', 'created_at',
        ]
        read_only_fields = ['invoice_number', 'created_at']


# ─── Notifications ─────────────────────────────────────────────────────────────

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id', 'customer', 'message', 'priority',
            'read', 'read_at', 'sent', 'sent_at', 'created_at',
        ]
        read_only_fields = ['created_at']


# ─── Categories ────────────────────────────────────────────────────────────────

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'created_at', 'updated_at']
        read_only_fields = ['created_at', 'updated_at']


# ─── Staff Users ───────────────────────────────────────────────────────────────

class StaffUserSerializer(serializers.ModelSerializer):
    """Serializer for managing staff users within a tenant."""
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'is_active', 'is_staff', 'role', 'date_joined', 'last_login',
        ]
        read_only_fields = ['date_joined', 'last_login']

    def get_role(self, obj):
        groups = obj.groups.values_list('name', flat=True)
        if 'Manager' in groups:
            return 'manager'
        elif 'Kitchen Staff' in groups:
            return 'kitchen_staff'
        elif 'Driver' in groups:
            return 'driver'
        elif obj.is_superuser:
            return 'admin'
        return 'staff'


class StaffUserCreateSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150, required=False, default='')
    last_name = serializers.CharField(max_length=150, required=False, default='')
    role = serializers.ChoiceField(
        choices=['manager', 'kitchen_staff', 'driver', 'staff'],
        default='staff',
    )
