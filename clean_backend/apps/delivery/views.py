from django.shortcuts import render
from django.http import JsonResponse
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.delivery.models import Delivery
from apps.delivery.serializers import DeliverySerializer


def index(request):
    return render(request, 'delivery/index.html')


def api_index(request):
    return JsonResponse({'message': 'delivery API endpoint'})


class DeliveryViewSet(viewsets.ModelViewSet):
    """
    Manage deliveries (admin view).

    Allows listing, assigning drivers, and updating delivery status.
    """
    serializer_class = DeliverySerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['status', 'driver']
    ordering = ['-created_at']
    search_fields = ['order__id', 'driver__name', 'driver_user__username']

    def get_queryset(self):
        user = self.request.user
        qs = Delivery.objects.select_related('order', 'driver', 'driver_user').all()
        
        # If user is a driver, only show their deliveries
        if hasattr(user, 'driver_profile'):
            return qs.filter(driver=user.driver_profile)
            
        return qs

    @action(detail=True, methods=['post'])
    def assign_driver(self, request, pk=None):
        """Assign or change the driver for a delivery."""
        delivery = self.get_object()
        driver_id = request.data.get('driver_id')
        if not driver_id:
            return Response(
                {'error': 'driver_id is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        from apps.driver.models import DeliveryDriver
        try:
            driver = DeliveryDriver.objects.get(pk=driver_id)
        except DeliveryDriver.DoesNotExist:
            return Response(
                {'error': 'Driver not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
        delivery.driver = driver
        delivery.save(update_fields=['driver'])
        return Response(DeliverySerializer(delivery).data)

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        """Update the delivery status."""
        delivery = self.get_object()
        new_status = request.data.get('status')
        valid = ['pending', 'in_transit', 'delivered', 'failed']
        if new_status not in valid:
            return Response(
                {'error': f'Invalid status. Allowed: {", ".join(valid)}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        delivery.status = new_status
        if new_status == 'in_transit' and not delivery.pickup_time:
            delivery.pickup_time = timezone.now()
        elif new_status == 'delivered' and not delivery.delivery_time:
            delivery.delivery_time = timezone.now()
        delivery.save()
        return Response(DeliverySerializer(delivery).data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Delivery stats for the dashboard."""
        today = timezone.now().date()
        qs = self.get_queryset()
        today_qs = qs.filter(created_at__date=today)
        return Response({
            'total': qs.count(),
            'today': today_qs.count(),
            'pending': qs.filter(status='pending').count(),
            'in_transit': qs.filter(status='in_transit').count(),
            'delivered': qs.filter(status='delivered').count(),
            'failed': qs.filter(status='failed').count(),
        })
