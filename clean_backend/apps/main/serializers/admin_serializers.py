"""
Serializers for tenant-admin facing APIs.
These are used by kitchen staff, managers, and tenant admins.
"""
from rest_framework import serializers
from django.contrib.auth.models import User

from apps.main.models import (
    Order, Subscription, CustomerProfile, Invoice, InvoiceItem,
    Notification, CustomerRegistrationRequest, Category, Address,
    MealSlot, DailyMenu, DailyMenuItem, MenuItem, MealPackage,
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


# ─── Address (admin view) ────────────────────────────────────────────────────

class AddressAdminSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)

    class Meta:
        model = Address
        fields = [
            'id', 'customer', 'customer_name',
            'street', 'city', 'building_name',
            'floor_number', 'flat_number',
            'is_default', 'status',
            'admin_notes', 'reason',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class AddressCreateSerializer(serializers.ModelSerializer):
    """For creating addresses from admin side (auto-approved as active)."""

    class Meta:
        model = Address
        fields = [
            'customer', 'street', 'city', 'building_name',
            'floor_number', 'flat_number', 'is_default',
        ]


# ─── Customers (admin view) ───────────────────────────────────────────────────

class CustomerProfileAdminSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    full_name = serializers.CharField(source='user.get_full_name', read_only=True)
    addresses = AddressAdminSerializer(many=True, read_only=True)

    class Meta:
        model = CustomerProfile
        fields = [
            'id', 'username', 'email', 'full_name',
            'name', 'phone', 'emirates_id', 'zone',
            'wallet_balance', 'loyalty_points', 'loyalty_tier',
            'preferred_communication', 'addresses',
            'created_at', 'updated_at',
            'first_name', 'last_name',
        ]
        read_only_fields = ['wallet_balance', 'loyalty_points', 'created_at', 'updated_at', 'username']

    # Explicitly define these fields so they are writable
    first_name = serializers.CharField(source='user.first_name', required=False)
    last_name = serializers.CharField(source='user.last_name', required=False)
    email = serializers.EmailField(source='user.email', required=False)

    def update(self, instance, validated_data):
        # Extract user data - DRF nests it because of source='user.field'
        user_data = validated_data.pop('user', {})
        
        # Update CustomerProfile fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Update User fields if provided
        user = instance.user
        if user_data:
            user_updated = False
            if 'first_name' in user_data:
                user.first_name = user_data['first_name']
                user_updated = True
            if 'last_name' in user_data:
                user.last_name = user_data['last_name']
                user_updated = True
            if 'email' in user_data:
                new_email = user_data['email']
                if new_email and user.email != new_email:
                    if User.objects.filter(email=new_email).exclude(pk=user.pk).exists():
                         raise serializers.ValidationError({"email": "This email is already in use."})
                user.email = new_email
                user_updated = True
            
            if user_updated:
                user.save()

        return instance


class CustomerProfileCreateSerializer(serializers.Serializer):
    """
    Admin-facing serializer to create a new customer.
    Creates a Django User + CustomerProfile + (optional) Address in the tenant DB.
    """
    name = serializers.CharField(max_length=100)
    phone = serializers.CharField(max_length=20)
    email = serializers.EmailField(required=False, allow_blank=True, default='')
    emirates_id = serializers.CharField(max_length=20, required=False, allow_blank=True, default='')
    zone = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    preferred_communication = serializers.ChoiceField(
        choices=[('whatsapp', 'WhatsApp'), ('sms', 'SMS'), ('email', 'Email'), ('none', 'None')],
        default='whatsapp',
        required=False,
    )
    # Structured address fields (all optional)
    street = serializers.CharField(max_length=200, required=False, allow_blank=True, default='')
    city = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    building_name = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    floor_number = serializers.CharField(max_length=10, required=False, allow_blank=True, default='')
    flat_number = serializers.CharField(max_length=10, required=False, allow_blank=True, default='')

    def validate_phone(self, value):
        if CustomerProfile.objects.filter(phone=value).exists():
            raise serializers.ValidationError("A customer with this phone number already exists.")
        return value

    def validate_email(self, value):
        if value and User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def create(self, validated_data):
        import uuid
        name = validated_data['name']
        phone = validated_data['phone']
        email = validated_data.get('email', '')

        # Extract address fields
        street = validated_data.pop('street', '')
        city = validated_data.pop('city', '')
        building_name = validated_data.pop('building_name', '')
        floor_number = validated_data.pop('floor_number', '')
        flat_number = validated_data.pop('flat_number', '')

        # Generate a unique username from the phone number
        username = f"cust_{phone.replace('+', '').replace(' ', '').replace('-', '')}"
        if User.objects.filter(username=username).exists():
            username = f"{username}_{uuid.uuid4().hex[:6]}"

        # Create User in the tenant DB (router handles this)
        user = User.objects.create_user(
            username=username,
            email=email,
            first_name=name.split()[0] if name else '',
            last_name=' '.join(name.split()[1:]) if len(name.split()) > 1 else '',
            is_active=True,
            is_staff=False,
        )
        user.set_unusable_password()
        user.save()

        # Create CustomerProfile in the tenant DB
        customer = CustomerProfile.objects.create(
            user=user,
            name=name,
            phone=phone,
            emirates_id=validated_data.get('emirates_id', ''),
            zone=validated_data.get('zone', ''),
            preferred_communication=validated_data.get('preferred_communication', 'whatsapp'),
        )

        # Create Address if any address field was provided
        has_address = any([street, city, building_name, floor_number, flat_number])
        if has_address:
            Address.objects.create(
                customer=customer,
                street=street,
                city=city,
                building_name=building_name,
                floor_number=floor_number,
                flat_number=flat_number,
                is_default=True,
                status='active',  # Admin-created → auto-approved
                requested_by=self.context.get('request', {}).user
                    if hasattr(self.context.get('request', {}), 'user') else None,
            )

        return customer


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
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)
    item_count = serializers.SerializerMethodField()

    class Meta:
        model = DailyMenu
        fields = [
            'id', 'menu_date', 'meal_slot', 'meal_slot_name',
            'meal_slot_code', 'diet_type', 'diet_type_display',
            'status', 'item_count', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def get_item_count(self, obj):
        # Use annotated value if available, otherwise fall back to DB count
        if hasattr(obj, 'item_count'):
            return obj.item_count
        return obj.items.count()


class DailyMenuDetailSerializer(serializers.ModelSerializer):
    """Full serializer with nested items for detail view / editing."""
    meal_slot_name = serializers.CharField(source='meal_slot.name', read_only=True)
    meal_slot_code = serializers.CharField(source='meal_slot.code', read_only=True)
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)
    items = DailyMenuItemReadSerializer(many=True, read_only=True)
    item_count = serializers.SerializerMethodField()

    def get_item_count(self, obj):
        if hasattr(obj, 'item_count'):
            return obj.item_count
        return obj.items.count()

    class Meta:
        model = DailyMenu
        fields = [
            'id', 'menu_date', 'meal_slot', 'meal_slot_name',
            'meal_slot_code', 'diet_type', 'diet_type_display',
            'status', 'notes',
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
      "diet_type": "veg",
      "notes": "",
      "items": [
        {"master_item": 3, "override_price": null, "portion_label": ""},
        {"master_item": 7, "override_price": "12.50", "portion_label": ""}
      ]
    }
    """
    items = DailyMenuItemWriteSerializer(many=True, required=False)

    class Meta:
        model = DailyMenu
        fields = ['id', 'menu_date', 'meal_slot', 'diet_type', 'notes', 'items']

    def validate(self, attrs):
        menu_date = attrs.get('menu_date')
        meal_slot = attrs.get('meal_slot')
        diet_type = attrs.get('diet_type', 'nonveg')
        instance = self.instance

        # On create, check uniqueness (date + slot + diet_type)
        if not instance:
            if DailyMenu.objects.filter(
                menu_date=menu_date, meal_slot=meal_slot, diet_type=diet_type,
            ).exists():
                diet_label = dict(DailyMenu.DIET_CHOICES).get(diet_type, diet_type)
                raise serializers.ValidationError(
                    f"A {diet_label} daily menu for {menu_date} / {meal_slot.name} already exists."
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


# ─── Meal Packages ─────────────────────────────────────────────────────────

class MealPackageSerializer(serializers.ModelSerializer):
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)
    duration_display = serializers.CharField(source='get_duration_display', read_only=True)

    class Meta:
        model = MealPackage
        fields = [
            'id', 'name', 'description', 'price', 'currency',
            'diet_type', 'diet_type_display',
            'duration', 'duration_display', 'duration_days',
            'meals_per_day', 'portion_label',
            'sort_order', 'is_active',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
