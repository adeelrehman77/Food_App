"""
Admin-facing ViewSets for delivery management.
Zone, Route, Driver, Schedule, and Assignment CRUD.
"""
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.driver.models import (
    Zone, Route, DeliveryDriver, DeliveryAssignment, DeliverySchedule,
)
from apps.driver.serializers.admin_serializers import (
    ZoneSerializer, RouteSerializer, DeliveryDriverSerializer,
    DeliveryAssignmentAdminSerializer, DeliveryScheduleSerializer,
)
from apps.driver.permissions import IsLogisticsAdmin


class ZoneViewSet(viewsets.ModelViewSet):
    """CRUD for delivery zones."""
    queryset = Zone.objects.annotate(route_count=Count('routes')).order_by('name')
    serializer_class = ZoneSerializer
    permission_classes = [permissions.IsAuthenticated, IsLogisticsAdmin]
    filterset_fields = ['is_active']
    search_fields = ['name']
    ordering = ['name']

    @action(detail=True, methods=['get'])
    def drivers(self, request, pk=None):
        """List drivers assigned to this zone."""
        zone = self.get_object()
        drivers = zone.assigned_drivers.all()
        return Response(DeliveryDriverSerializer(drivers, many=True).data)


class RouteViewSet(viewsets.ModelViewSet):
    """CRUD for delivery routes within zones."""
    queryset = Route.objects.select_related('zone').all()
    serializer_class = RouteSerializer
    permission_classes = [permissions.IsAuthenticated, IsLogisticsAdmin]
    filterset_fields = ['zone', 'is_active']
    search_fields = ['name']

    @action(detail=True, methods=['get'])
    def drivers(self, request, pk=None):
        """List drivers assigned to this route."""
        route = self.get_object()
        drivers = route.assigned_drivers.all()
        return Response(DeliveryDriverSerializer(drivers, many=True).data)


class DeliveryDriverViewSet(viewsets.ModelViewSet):
    """CRUD for delivery drivers with zone/route assignment support."""
    queryset = DeliveryDriver.objects.prefetch_related('zones', 'routes').all()
    serializer_class = DeliveryDriverSerializer
    permission_classes = [permissions.IsAuthenticated, IsLogisticsAdmin]
    filterset_fields = ['is_active']
    search_fields = ['name', 'phone']

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Toggle a driver's active status."""
        driver = self.get_object()
        driver.is_active = not driver.is_active
        driver.save(update_fields=['is_active'])
        return Response(DeliveryDriverSerializer(driver).data)

    @action(detail=True, methods=['post'])
    def assign_zones(self, request, pk=None):
        """Set the zones for this driver. Send {"zone_ids": [1,2,3]}."""
        driver = self.get_object()
        zone_ids = request.data.get('zone_ids', [])
        zones = Zone.objects.filter(pk__in=zone_ids)
        driver.zones.set(zones)
        return Response(DeliveryDriverSerializer(driver).data)

    @action(detail=True, methods=['post'])
    def assign_routes(self, request, pk=None):
        """Set the routes for this driver. Send {"route_ids": [1,2,3]}."""
        driver = self.get_object()
        route_ids = request.data.get('route_ids', [])
        routes = Route.objects.filter(pk__in=route_ids)
        driver.routes.set(routes)
        return Response(DeliveryDriverSerializer(driver).data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Driver stats for the dashboard."""
        qs = self.get_queryset()
        today = timezone.now().date()
        return Response({
            'total': qs.count(),
            'active': qs.filter(is_active=True).count(),
            'inactive': qs.filter(is_active=False).count(),
            'on_delivery_today': DeliveryAssignment.objects.filter(
                delivery_status__date=today,
                delivery_status__status__in=['out_for_delivery', 'preparing'],
            ).values('driver').distinct().count(),
        })


class DeliveryScheduleViewSet(viewsets.ModelViewSet):
    """CRUD for delivery time-slot schedules."""
    queryset = DeliverySchedule.objects.select_related('zone').all()
    serializer_class = DeliveryScheduleSerializer
    permission_classes = [permissions.IsAuthenticated, IsLogisticsAdmin]
    filterset_fields = ['zone', 'day_of_week', 'is_active']


class DeliveryAssignmentAdminViewSet(viewsets.ModelViewSet):
    """Assign and manage delivery assignments."""
    queryset = DeliveryAssignment.objects.select_related(
        'delivery_status', 'driver',
    ).all()
    serializer_class = DeliveryAssignmentAdminSerializer
    permission_classes = [permissions.IsAuthenticated, IsLogisticsAdmin]
    filterset_fields = ['driver', 'delivery_status__date']
    ordering = ['-assigned_at']
