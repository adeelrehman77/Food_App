"""
Serializers for tenant-admin facing APIs.
These are used by kitchen staff, managers, and tenant admins.
"""
from rest_framework import serializers
from django.contrib.auth.models import User

from apps.main.models import (
    Order, Subscription, CustomerProfile, Invoice, InvoiceItem,
    Notification, CustomerRegistrationRequest, Category,
    MealSlot, DailyMenu, DailyMenuItem, MenuItem,
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


# ─── Meal Slots ───────────────────────────────────────────────────────────────

class MealSlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = MealSlot
        fields = [
            'id', 'name', 'code', 'cutoff_time',
            'sort_order', 'is_active', 'created_at',
        ]
        read_only_fields = ['created_at']


# ─── Daily Menu Items ─────────────────────────────────────────────────────────

class DailyMenuItemReadSerializer(serializers.ModelSerializer):
    """Read serializer – includes master item details."""
    master_item_name = serializers.CharField(source='master_item.name', read_only=True)
    master_item_price = serializers.DecimalField(
        source='master_item.price', max_digits=10, decimal_places=2, read_only=True,
    )
    effective_price = serializers.DecimalField(
        max_digits=10, decimal_places=2, read_only=True,
    )
    category_name = serializers.CharField(
        source='master_item.category.name', read_only=True, default='',
    )
    master_item_image = serializers.ImageField(
        source='master_item.image', read_only=True,
    )

    class Meta:
        model = DailyMenuItem
        fields = [
            'id', 'master_item', 'master_item_name', 'master_item_price',
            'master_item_image', 'category_name',
            'override_price', 'effective_price', 'portion_label',
            'sort_order', 'created_at',
        ]


class DailyMenuItemWriteSerializer(serializers.ModelSerializer):
    """Write serializer – accepts master_item id + optional overrides."""
    class Meta:
        model = DailyMenuItem
        fields = [
            'id', 'master_item', 'override_price',
            'portion_label', 'sort_order',
        ]


# ─── Daily Menu ───────────────────────────────────────────────────────────────

class DailyMenuListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list / calendar views."""
    meal_slot_name = serializers.CharField(source='meal_slot.name', read_only=True)
    meal_slot_code = serializers.CharField(source='meal_slot.code', read_only=True)
    item_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DailyMenu
        fields = [
            'id', 'menu_date', 'meal_slot', 'meal_slot_name',
            'meal_slot_code', 'status', 'item_count', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class DailyMenuDetailSerializer(serializers.ModelSerializer):
    """Full serializer with nested items for detail view / editing."""
    meal_slot_name = serializers.CharField(source='meal_slot.name', read_only=True)
    meal_slot_code = serializers.CharField(source='meal_slot.code', read_only=True)
    items = DailyMenuItemReadSerializer(many=True, read_only=True)
    item_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DailyMenu
        fields = [
            'id', 'menu_date', 'meal_slot', 'meal_slot_name',
            'meal_slot_code', 'status', 'notes',
            'items', 'item_count',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_by', 'created_at', 'updated_at']


class DailyMenuCreateSerializer(serializers.ModelSerializer):
    """
    Accepts a flat payload with nested items for create / update.
    {
      "menu_date": "2026-02-15",
      "meal_slot": 1,
      "notes": "",
      "items": [
        {"master_item": 3, "override_price": null, "portion_label": "Regular"},
        {"master_item": 7, "override_price": "12.50", "portion_label": "Family Pack"}
      ]
    }
    """
    items = DailyMenuItemWriteSerializer(many=True, required=False)

    class Meta:
        model = DailyMenu
        fields = ['id', 'menu_date', 'meal_slot', 'notes', 'items']

    def validate(self, attrs):
        menu_date = attrs.get('menu_date')
        meal_slot = attrs.get('meal_slot')
        instance = self.instance

        # On create, check uniqueness
        if not instance:
            if DailyMenu.objects.filter(menu_date=menu_date, meal_slot=meal_slot).exists():
                raise serializers.ValidationError(
                    f"A daily menu for {menu_date} / {meal_slot.name} already exists."
                )
        return attrs

    def create(self, validated_data):
        items_data = validated_data.pop('items', [])
        validated_data['created_by'] = self.context['request'].user
        daily_menu = DailyMenu.objects.create(**validated_data)
        self._save_items(daily_menu, items_data)
        return daily_menu

    def update(self, instance, validated_data):
        items_data = validated_data.pop('items', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if items_data is not None:
            # Replace all items
            instance.items.all().delete()
            self._save_items(instance, items_data)
        return instance

    @staticmethod
    def _save_items(daily_menu, items_data):
        for idx, item_data in enumerate(items_data):
            item_data['sort_order'] = item_data.get('sort_order', idx)
            DailyMenuItem.objects.create(daily_menu=daily_menu, **item_data)

    def to_representation(self, instance):
        """Return full detail representation after write."""
        return DailyMenuDetailSerializer(instance, context=self.context).data
