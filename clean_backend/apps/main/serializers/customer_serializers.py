from django.apps import apps
from rest_framework import serializers
from apps.main.models import Subscription, WalletTransaction, Address, MenuItem, MealSlot, CustomerProfile, Menu

class MenuItemSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)
    inventory_item_id = serializers.PrimaryKeyRelatedField(
        source='inventory_item', read_only=True,
    )

    class Meta:
        model = MenuItem
        fields = [
            'id', 'name', 'description', 'price', 'image',
            'calories', 'allergens',
            'category', 'category_name',
            'diet_type', 'diet_type_display',
            'is_available', 'inventory_item_id',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

class MealSlotBriefSerializer(serializers.ModelSerializer):
    """Brief serializer for MealSlot (subscription time_slot)."""
    time = serializers.SerializerMethodField()

    class Meta:
        model = MealSlot
        fields = ['id', 'name', 'code', 'cutoff_time', 'time']

    def get_time(self, obj):
        if obj and obj.cutoff_time:
            return obj.cutoff_time.strftime('%H:%M')
        return ''

class MenuSerializer(serializers.ModelSerializer):
    class Meta:
        model = apps.get_model('main', 'Menu')
        fields = ['id', 'name', 'description', 'price']

class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = [
            'id', 'street', 'city', 'building_name', 
            'floor_number', 'flat_number', 'is_default', 
            'status', 'admin_notes', 'reason'
        ]
        read_only_fields = ['customer', 'status', 'admin_notes']

class SubscriptionSerializer(serializers.ModelSerializer):
    menus = MenuSerializer(many=True, read_only=True)
    menu_ids = serializers.PrimaryKeyRelatedField(
        source='menus', many=True, queryset=apps.get_model('main', 'Menu').objects.all(), write_only=True
    )
    time_slot_details = MealSlotBriefSerializer(source='time_slot', read_only=True)
    lunch_address = AddressSerializer(read_only=True)
    dinner_address = AddressSerializer(read_only=True)

    class Meta:
        model = Subscription
        fields = [
            'id', 'status', 'start_date', 'end_date',
            'menus', 'menu_ids',
            'time_slot', 'time_slot_details',
            'lunch_address', 'dinner_address',
            'selected_days', 'payment_mode', 'total_cost',
            'created_at'
        ]
        read_only_fields = ['status', 'created_at', 'total_cost']

class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = ['id', 'amount', 'transaction_type', 'description', 'created_at']


