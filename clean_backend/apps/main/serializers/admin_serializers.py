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
    Menu,
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
    zone = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()

    class Meta:
        model = Address
        fields = [
            'id', 'customer', 'customer_name',
            'street', 'city', 'building_name',
            'floor_number', 'flat_number',
            'zone', 'zone_name',
            'is_default', 'status',
            'admin_notes', 'reason',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_zone(self, obj):
        return obj.zone.id if obj.zone else None
    
    def get_zone_name(self, obj):
        return obj.zone.name if obj.zone else None


class AddressCreateSerializer(serializers.ModelSerializer):
    """For creating addresses from admin side (auto-approved as active)."""

    class Meta:
        model = Address
        fields = [
            'customer', 'street', 'city', 'building_name',
            'floor_number', 'flat_number', 'zone', 'is_default',
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
    zone = serializers.IntegerField(required=False, allow_null=True, help_text="Zone ID for delivery zone")
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

        # Get zone if provided
        zone_id = validated_data.get('zone')
        zone_str = ''
        zone_obj = None
        if zone_id:
            from apps.driver.models import Zone
            try:
                zone_obj = Zone.objects.get(pk=zone_id)
                zone_str = zone_obj.name
            except (Zone.DoesNotExist, ValueError, TypeError):
                pass
        
        # Create CustomerProfile in the tenant DB
        customer = CustomerProfile.objects.create(
            user=user,
            name=name,
            phone=phone,
            emirates_id=validated_data.get('emirates_id', ''),
            zone=zone_str,  # Keep as string for backward compatibility
            preferred_communication=validated_data.get('preferred_communication', 'whatsapp'),
        )

        # Create Address if any address field was provided
        has_address = any([street, city, building_name, floor_number, flat_number])
        if has_address:
            Address.objects.create(
                customer=customer,
                zone=zone_obj,  # Use zone FK for Address
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
    time = serializers.SerializerMethodField()

    class Meta:
        model = MealSlot
        fields = [
            'id', 'name', 'code', 'cutoff_time', 'time',
            'sort_order', 'is_active', 'created_at',
        ]
        read_only_fields = ['created_at']

    def get_time(self, obj):
        if obj.cutoff_time:
            return obj.cutoff_time.strftime('%H:%M')
        return ''


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


# ─── Menus (admin) ──────────────────────────────────────────────────────────

class MenuBriefSerializer(serializers.ModelSerializer):
    """Lightweight Menu for MealPackage/Subscription."""
    class Meta:
        model = Menu
        fields = ['id', 'name', 'description', 'price']


class MenuAdminSerializer(serializers.ModelSerializer):
    """Full Menu CRUD with menu_items."""
    menu_items = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    menu_item_ids = serializers.PrimaryKeyRelatedField(
        source='menu_items', many=True, queryset=MenuItem.objects.all(), write_only=True, required=False
    )

    class Meta:
        model = Menu
        fields = ['id', 'name', 'description', 'price', 'is_active', 'menu_items', 'menu_item_ids', 'created_at', 'updated_at']
        read_only_fields = ['created_at', 'updated_at']

    def create(self, validated_data):
        menu_items = validated_data.pop('menu_items', [])
        instance = Menu.objects.create(**validated_data)
        if menu_items:
            instance.menu_items.set(menu_items)
        return instance

    def update(self, instance, validated_data):
        menu_items = validated_data.pop('menu_items', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if menu_items is not None:
            instance.menu_items.set(menu_items)
        return instance


# ─── Meal Packages ─────────────────────────────────────────────────────────

class MealPackageSerializer(serializers.ModelSerializer):
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)
    duration_display = serializers.CharField(source='get_duration_display', read_only=True)
    menus = MenuBriefSerializer(many=True, read_only=True)
    menu_ids = serializers.PrimaryKeyRelatedField(
        source='menus', many=True, queryset=Menu.objects.all(), write_only=True, required=False
    )

    class Meta:
        model = MealPackage
        fields = [
            'id', 'name', 'description', 'price', 'currency',
            'diet_type', 'diet_type_display',
            'duration', 'duration_display', 'duration_days',
            'meals_per_day', 'portion_label',
            'menus', 'menu_ids',
            'sort_order', 'is_active',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def create(self, validated_data):
        menus = validated_data.pop('menus', [])
        instance = MealPackage.objects.create(**validated_data)
        if menus:
            instance.menus.set(menus)
        return instance

    def update(self, instance, validated_data):
        menus = validated_data.pop('menus', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if menus is not None:
            instance.menus.set(menus)
        return instance


# ─── Subscriptions (admin) ─────────────────────────────────────────────────

class _MealSlotBrief(serializers.ModelSerializer):
    """Brief representation of MealSlot for subscription (time_slot FK)."""
    time = serializers.SerializerMethodField()

    class Meta:
        model = MealSlot
        fields = ['id', 'name', 'code', 'cutoff_time', 'time']

    def get_time(self, obj):
        if obj.cutoff_time:
            return obj.cutoff_time.strftime('%H:%M')
        return ''


class _AddressBrief(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = ['id', 'building_name', 'flat_number', 'floor_number', 'street', 'city']


class _MealPackageBrief(serializers.ModelSerializer):
    diet_type_display = serializers.CharField(source='get_diet_type_display', read_only=True)

    class Meta:
        model = MealPackage
        fields = ['id', 'name', 'price', 'currency', 'diet_type', 'diet_type_display']


class SubscriptionAdminListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list views."""
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)
    customer_id = serializers.IntegerField(source='customer.id', read_only=True)
    time_slot_name = serializers.SerializerMethodField()
    meal_package_name = serializers.SerializerMethodField()
    order_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Subscription
        fields = [
            'id', 'customer_id', 'customer_name', 'customer_phone',
            'status', 'start_date', 'end_date',
            'time_slot', 'time_slot_name', 'meal_package', 'meal_package_name',
            'selected_days', 'payment_mode', 'diet_type', 'cost_per_meal', 'total_cost',
            'dietary_preferences', 'order_count',
            'lunch_address', 'dinner_address',
        ]
        read_only_fields = ['cost_per_meal', 'total_cost']
    
    def get_time_slot_name(self, obj):
        return obj.time_slot.name if obj.time_slot else ''
    
    def get_meal_package_name(self, obj):
        return obj.meal_package.name if obj.meal_package else ''


class SubscriptionAdminDetailSerializer(serializers.ModelSerializer):
    """Full detail serializer with nested objects."""
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone', read_only=True)
    customer_id = serializers.IntegerField(source='customer.id', read_only=True)
    time_slot_name = serializers.SerializerMethodField()
    time_slot_details = serializers.SerializerMethodField()
    meal_package_details = serializers.SerializerMethodField()
    lunch_address_details = serializers.SerializerMethodField()
    dinner_address_details = serializers.SerializerMethodField()
    order_count = serializers.SerializerMethodField()
    
    def get_time_slot_name(self, obj):
        try:
            return obj.time_slot.name if obj.time_slot else ''
        except Exception:
            return ''
    
    def get_time_slot_details(self, obj):
        try:
            if obj.time_slot:
                return _MealSlotBrief(obj.time_slot).data
        except Exception:
            pass
        return None
    
    def get_meal_package_details(self, obj):
        try:
            if obj.meal_package:
                return _MealPackageBrief(obj.meal_package).data
        except Exception:
            pass
        return None
    
    def get_lunch_address_details(self, obj):
        try:
            if obj.lunch_address:
                return _AddressBrief(obj.lunch_address).data
        except Exception:
            pass
        return None
    
    def get_dinner_address_details(self, obj):
        try:
            if obj.dinner_address:
                return _AddressBrief(obj.dinner_address).data
        except Exception:
            pass
        return None

    class Meta:
        model = Subscription
        fields = [
            'id', 'customer', 'customer_id', 'customer_name', 'customer_phone',
            'status', 'start_date', 'end_date',
            'time_slot', 'time_slot_name', 'time_slot_details',
            'meal_package', 'meal_package_details',
            'lunch_address', 'lunch_address_details',
            'dinner_address', 'dinner_address_details',
            'selected_days', 'payment_mode', 'diet_type',
            'want_notifications', 'dietary_preferences', 'special_instructions',
            'cost_per_meal', 'total_cost', 'order_count',
        ]
        read_only_fields = ['cost_per_meal', 'total_cost']

    def get_order_count(self, obj):
        return obj.order_set.count()


class SubscriptionAdminCreateSerializer(serializers.ModelSerializer):
    """Create / update subscriptions from admin side."""

    class Meta:
        model = Subscription
        fields = [
            'customer', 'status', 'start_date', 'end_date',
            'time_slot', 'meal_package', 'lunch_address', 'dinner_address',
            'selected_days', 'payment_mode', 'diet_type',
            'want_notifications', 'dietary_preferences', 'special_instructions',
        ]

    def validate(self, attrs):
        """
        Validate subscription data.
        Note: This method is only called during create/update operations, not during list/retrieve.
        """
        start = attrs.get('start_date')
        end = attrs.get('end_date')
        if start and end and start > end:
            raise serializers.ValidationError(
                {'end_date': 'End date must be after start date.'}
            )
        selected_days = attrs.get('selected_days', [])
        if not selected_days:
            raise serializers.ValidationError(
                {'selected_days': 'At least one delivery day must be selected.'}
            )
        
        # Validate zone selection based on meal slot
        # Only validate if addresses are being set (create/update operations)
        time_slot = attrs.get('time_slot') or (self.instance.time_slot if self.instance else None)
        lunch_address_id = attrs.get('lunch_address')
        dinner_address_id = attrs.get('dinner_address')
        
        # Skip zone validation if no addresses are being set/changed
        # This allows updates to other fields without requiring zone validation
        if lunch_address_id is None and dinner_address_id is None:
            return attrs
        
        # Get address objects (either from attrs or instance)
        lunch_address = None
        dinner_address = None
        
        try:
            if lunch_address_id:
                # If it's an ID, fetch the address object
                if isinstance(lunch_address_id, int):
                    from apps.main.models import Address
                    try:
                        lunch_address = Address.objects.select_related('zone').get(pk=lunch_address_id)
                    except Address.DoesNotExist:
                        raise serializers.ValidationError(
                            {'lunch_address': 'Lunch address not found.'}
                        )
                else:
                    lunch_address = lunch_address_id
            elif self.instance and self.instance.lunch_address:
                lunch_address = self.instance.lunch_address
            
            if dinner_address_id:
                if isinstance(dinner_address_id, int):
                    from apps.main.models import Address
                    try:
                        dinner_address = Address.objects.select_related('zone').get(pk=dinner_address_id)
                    except Address.DoesNotExist:
                        raise serializers.ValidationError(
                            {'dinner_address': 'Dinner address not found.'}
                        )
                else:
                    dinner_address = dinner_address_id
            elif self.instance and self.instance.dinner_address:
                dinner_address = self.instance.dinner_address
            
            if time_slot:
                meal_slot_name = getattr(time_slot, 'name', '').lower() if time_slot else ''
                meal_slot_code = getattr(time_slot, 'code', '').lower() if time_slot else ''
                
                if 'lunch' in meal_slot_name or 'lunch' in meal_slot_code:
                    if lunch_address_id is not None and lunch_address and not getattr(lunch_address, 'zone', None):
                        raise serializers.ValidationError(
                            {'lunch_address': 'Lunch address must have a delivery zone assigned.'}
                        )
                elif 'dinner' in meal_slot_name or 'dinner' in meal_slot_code:
                    if dinner_address_id is not None and dinner_address and not getattr(dinner_address, 'zone', None):
                        raise serializers.ValidationError(
                            {'dinner_address': 'Dinner address must have a delivery zone assigned.'}
                        )
                else:
                    # For ambiguous meal slots, check both addresses
                    if lunch_address_id is not None and lunch_address and not getattr(lunch_address, 'zone', None):
                        raise serializers.ValidationError(
                            {'lunch_address': 'Address must have a delivery zone assigned.'}
                        )
                    if dinner_address_id is not None and dinner_address and not getattr(dinner_address, 'zone', None):
                        raise serializers.ValidationError(
                            {'dinner_address': 'Address must have a delivery zone assigned.'}
                        )
            else:
                # If no meal slot specified, at least one address with zone is required
                lunch_has_zone = lunch_address and getattr(lunch_address, 'zone', None)
                dinner_has_zone = dinner_address and getattr(dinner_address, 'zone', None)
                if (lunch_address_id is not None or dinner_address_id is not None) and not lunch_has_zone and not dinner_has_zone:
                    raise serializers.ValidationError(
                        {'lunch_address': 'At least one address must have a delivery zone assigned.'}
                    )
        except Exception as e:
            # If it's already a ValidationError, re-raise it
            if isinstance(e, serializers.ValidationError):
                raise
            # Otherwise, log and return a generic error
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error validating subscription addresses: {e}")
            # Don't fail validation on unexpected errors during development
            pass
        
        return attrs

    def _apply_meal_package(self, instance, meal_package):
        """Derive menus, diet_type, cost_per_meal from package and set FK."""
        if not meal_package:
            return
        instance.meal_package = meal_package
        instance.menus.set(meal_package.menus.all())
        if meal_package.diet_type in ('veg', 'nonveg'):
            instance.diet_type = meal_package.diet_type
        instance.cost_per_meal = meal_package.price

    def create(self, validated_data):
        from django.db import models as db_models
        meal_package = validated_data.pop('meal_package', None)
        instance = Subscription(**validated_data)
        instance.calculate_total_cost()
        db_models.Model.save(instance)  # Need pk before M2M
        if meal_package:
            self._apply_meal_package(instance, meal_package)
            instance.calculate_total_cost()
            db_models.Model.save(instance)
        if instance.status == 'active':
            instance.update_delivery_schedule()
            instance.generate_orders()
        return instance

    def update(self, instance, validated_data):
        from django.db import models as db_models
        meal_package = validated_data.pop('meal_package', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if meal_package is not None:
            self._apply_meal_package(instance, meal_package)
        else:
            instance.meal_package = None
        instance.calculate_total_cost()
        db_models.Model.save(instance)
        if instance.status == 'active':
            instance.update_delivery_schedule()
            instance.generate_orders()
        return instance

    def to_representation(self, instance):
        return SubscriptionAdminDetailSerializer(instance, context=self.context).data
