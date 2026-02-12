"""
Admin-facing ViewSets for delivery management.
Zone, Route, Driver, Schedule, and Assignment CRUD.
"""
from django.db.models import Count
from rest_framework import viewsets, permissions

from apps.driver.models import (
    Zone, Route, DeliveryDriver, DeliveryAssignment, DeliverySchedule,
)
from apps.driver.serializers.admin_serializers import (
    ZoneSerializer, RouteSerializer, DeliveryDriverSerializer,
    DeliveryAssignmentAdminSerializer, DeliveryScheduleSerializer,
)


class ZoneViewSet(viewsets.ModelViewSet):
    """CRUD for delivery zones."""
    queryset = Zone.objects.annotate(route_count=Count('routes')).all()
    serializer_class = ZoneSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['is_active']
    search_fields = ['name']


class RouteViewSet(viewsets.ModelViewSet):
    """CRUD for delivery routes within zones."""
    queryset = Route.objects.select_related('zone').all()
    serializer_class = RouteSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['zone', 'is_active']
    search_fields = ['name']


class DeliveryDriverViewSet(viewsets.ModelViewSet):
    """CRUD for delivery drivers."""
    queryset = DeliveryDriver.objects.all()
    serializer_class = DeliveryDriverSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['is_active']
    search_fields = ['name', 'phone']


class DeliveryScheduleViewSet(viewsets.ModelViewSet):
    """CRUD for delivery time-slot schedules."""
    queryset = DeliverySchedule.objects.select_related('zone').all()
    serializer_class = DeliveryScheduleSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['zone', 'day_of_week', 'is_active']


class DeliveryAssignmentAdminViewSet(viewsets.ModelViewSet):
    """Assign and manage delivery assignments."""
    queryset = DeliveryAssignment.objects.select_related(
        'delivery_status', 'driver',
    ).all()
    serializer_class = DeliveryAssignmentAdminSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['driver', 'delivery_status__date']
    ordering = ['-assigned_at']
