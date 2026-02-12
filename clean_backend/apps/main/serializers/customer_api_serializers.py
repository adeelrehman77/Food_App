"""
Customer-facing serializers (Layer 3: B2C).
Used by the customer mobile app / web portal.
"""
from rest_framework import serializers
from apps.main.models import (
    MenuItem, Category, CustomerProfile, Order, Invoice, Notification,
)


# ─── Auth ──────────────────────────────────────────────────────────────────────

class CustomerRegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True, min_length=8)
    email = serializers.EmailField(required=False, allow_blank=True)
    first_name = serializers.CharField(max_length=150, required=False, default='')
    last_name = serializers.CharField(max_length=150, required=False, default='')


class CustomerLoginSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True)


# ─── Public Menu ───────────────────────────────────────────────────────────────

class PublicCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'description']


class PublicMenuItemSerializer(serializers.ModelSerializer):
    """
    Public-facing menu item serializer. Shows only what a customer needs
    to see — no inventory links or admin-only fields.
    """
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = MenuItem
        fields = [
            'id', 'name', 'description', 'price', 'image',
            'calories', 'allergens', 'category_name', 'is_available',
        ]


# ─── Customer Profile ─────────────────────────────────────────────────────────

class CustomerProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email')
    first_name = serializers.CharField(source='user.first_name')
    last_name = serializers.CharField(source='user.last_name')

    class Meta:
        model = CustomerProfile
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'name', 'phone', 'emirates_id',
            'wallet_balance', 'loyalty_points', 'loyalty_tier',
            'preferred_communication',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'wallet_balance', 'loyalty_points', 'loyalty_tier',
            'created_at', 'updated_at',
        ]

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        user = instance.user

        # Update User fields
        for attr, value in user_data.items():
            setattr(user, attr, value)
        user.save()

        # Update CustomerProfile fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        return instance


# ─── Customer Orders ──────────────────────────────────────────────────────────

class CustomerOrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = [
            'id', 'order_date', 'delivery_date', 'status',
            'quantity', 'special_instructions',
            'created_at', 'updated_at',
        ]
        read_only_fields = fields


# ─── Customer Invoices ────────────────────────────────────────────────────────

class CustomerInvoiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'date', 'due_date',
            'total', 'status', 'notes', 'created_at',
        ]
        read_only_fields = fields


# ─── Customer Notifications ───────────────────────────────────────────────────

class CustomerNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'message', 'priority', 'read', 'read_at', 'created_at']
        read_only_fields = fields


# ─── Wallet ───────────────────────────────────────────────────────────────────

class WalletTopUpSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=1)
