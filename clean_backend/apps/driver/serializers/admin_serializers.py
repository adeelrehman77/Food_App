"""
Admin-facing serializers for Zone, Route, DeliveryDriver, Schedule management.
"""
from rest_framework import serializers
from apps.driver.models import (
    Zone, Route, DeliveryDriver, DeliveryAssignment,
    DeliverySchedule, DeliveryStatus,
)


class ZoneSerializer(serializers.ModelSerializer):
    route_count = serializers.IntegerField(read_only=True, default=0)
    assigned_driver_count = serializers.SerializerMethodField()

    class Meta:
        model = Zone
        fields = [
            'id', 'name', 'description', 'delivery_fee',
            'estimated_delivery_time', 'is_active', 'route_count',
            'assigned_driver_count', 'created_at',
        ]
        read_only_fields = ['created_at']

    def get_assigned_driver_count(self, obj):
        return obj.assigned_drivers.count()


class RouteSerializer(serializers.ModelSerializer):
    zone_name = serializers.CharField(source='zone.name', read_only=True)
    assigned_driver_count = serializers.SerializerMethodField()

    class Meta:
        model = Route
        fields = [
            'id', 'name', 'zone', 'zone_name', 'description',
            'is_active', 'assigned_driver_count', 'created_at',
        ]
        read_only_fields = ['created_at']

    def get_assigned_driver_count(self, obj):
        return obj.assigned_drivers.count()


class _DriverZoneBrief(serializers.ModelSerializer):
    """Minimal zone info nested inside a driver response."""
    class Meta:
        model = Zone
        fields = ['id', 'name']


class _DriverRouteBrief(serializers.ModelSerializer):
    """Minimal route info nested inside a driver response."""
    zone_name = serializers.CharField(source='zone.name', read_only=True)

    class Meta:
        model = Route
        fields = ['id', 'name', 'zone', 'zone_name']


class DeliveryDriverSerializer(serializers.ModelSerializer):
    zone_ids = serializers.PrimaryKeyRelatedField(
        source='zones', queryset=Zone.objects.all(),
        many=True, required=False,
    )
    route_ids = serializers.PrimaryKeyRelatedField(
        source='routes', queryset=Route.objects.all(),
        many=True, required=False,
    )
    assigned_zones = _DriverZoneBrief(source='zones', many=True, read_only=True)
    assigned_routes = _DriverRouteBrief(source='routes', many=True, read_only=True)

    class Meta:
        model = DeliveryDriver
        fields = [
            'id', 'name', 'phone', 'email', 'vehicle_number',
            'vehicle_type', 'is_active',
            'zone_ids', 'route_ids',
            'assigned_zones', 'assigned_routes',
            'created_at',
        ]
        read_only_fields = ['created_at']

    def create(self, validated_data):
        zones = validated_data.pop('zones', [])
        routes = validated_data.pop('routes', [])
        # Create linked User account for new driver
        email = validated_data.get('email')
        phone = validated_data.get('phone')
        name = validated_data.get('name', '')
        
        # Generate username from phone
        username = phone.replace('+', '').replace(' ', '').replace('-', '')
        if not email:
            email = f"{username}@example.com"
            
        from django.contrib.auth.models import User, Group
        password = 'temp_password_123' # TODO: Email this to driver or allow them to set it
        
        user, created = User.objects.get_or_create(username=username, defaults={
            'email': email,
            'first_name': name.split()[0],
            'last_name': ' '.join(name.split()[1:]) if len(name.split()) > 1 else '',
            'is_staff': True,
            'is_active': True
        })
        if created:
            user.set_password(password)
            user.save()
        else:
            # Ensure existing user has staff access if being added as driver
            if not user.is_staff:
                user.is_staff = True
                user.save()
                
        # Assign to Driver group
        driver_group, _ = Group.objects.get_or_create(name='Driver')
        user.groups.add(driver_group)
        
        validated_data['user'] = user

        driver = super().create(validated_data)
        if zones:
            driver.zones.set(zones)
        if routes:
            driver.routes.set(routes)
        return driver

    def update(self, instance, validated_data):
        zones = validated_data.pop('zones', None)
        routes = validated_data.pop('routes', None)
        driver = super().update(instance, validated_data)
        if zones is not None:
            driver.zones.set(zones)
        if routes is not None:
            driver.routes.set(routes)
        return driver


class DeliveryScheduleSerializer(serializers.ModelSerializer):
    zone_name = serializers.CharField(source='zone.name', read_only=True)
    day_name = serializers.CharField(source='get_day_of_week_display', read_only=True)

    class Meta:
        model = DeliverySchedule
        fields = [
            'id', 'zone', 'zone_name', 'day_of_week', 'day_name',
            'start_time', 'end_time', 'max_deliveries', 'is_active',
        ]


class DeliveryAssignmentAdminSerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(source='driver.name', read_only=True, default='')
    delivery_date = serializers.DateField(source='delivery_status.date', read_only=True)
    delivery_status_value = serializers.CharField(source='delivery_status.status', read_only=True)

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'delivery_status', 'driver', 'driver_name',
            'delivery_date', 'delivery_status_value',
            'assigned_at', 'estimated_pickup_time', 'estimated_delivery_time',
            'notes',
        ]
        read_only_fields = ['assigned_at']
