from django.shortcuts import render
from django.http import JsonResponse
from django.utils import timezone
from rest_framework import viewsets, permissions, status as drf_status
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.kitchen.models import KitchenOrder
from apps.kitchen.serializers import KitchenOrderSerializer
from core.permissions.custom import IsKitchenStaff


def dashboard(request):
    return render(request, 'kitchen/dashboard.html')


def order_list(request):
    return JsonResponse({
        'orders': [],
        'message': 'Kitchen orders endpoint',
    })


class KitchenOrderViewSet(viewsets.ModelViewSet):
    """
    Kitchen Display System (KDS) API.

    Kitchen staff can:
    - List active kitchen orders for today
    - Claim an order (assign themselves)
    - Start/stop preparation
    - Mark an order as ready
    """
    serializer_class = KitchenOrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['order__status']
    ordering = ['created_at']

    def get_queryset(self):
        qs = KitchenOrder.objects.select_related(
            'order__subscription__customer__user', 'assigned_to',
        )
        # By default, show today's kitchen orders
        date = self.request.query_params.get('date')
        if date:
            qs = qs.filter(order__delivery_date=date)
        else:
            qs = qs.filter(order__delivery_date=timezone.now().date())

        # Filter by status if provided
        order_status = self.request.query_params.get('status')
        if order_status:
            qs = qs.filter(order__status=order_status)

        return qs

    @action(detail=True, methods=['post'])
    def claim(self, request, pk=None):
        """Assign the current user to this kitchen order."""
        kitchen_order = self.get_object()
        if kitchen_order.assigned_to and kitchen_order.assigned_to != request.user:
            return Response(
                {'error': 'This order is already claimed by another staff member.'},
                status=drf_status.HTTP_409_CONFLICT,
            )
        kitchen_order.assigned_to = request.user
        kitchen_order.save(update_fields=['assigned_to', 'updated_at'])
        return Response(self.get_serializer(kitchen_order).data)

    @action(detail=True, methods=['post'])
    def start_preparation(self, request, pk=None):
        """Record the start of preparation."""
        kitchen_order = self.get_object()
        if kitchen_order.preparation_start_time:
            return Response(
                {'error': 'Preparation already started.'},
                status=drf_status.HTTP_400_BAD_REQUEST,
            )
        kitchen_order.preparation_start_time = timezone.now()
        kitchen_order.order.status = 'preparing'
        kitchen_order.order.save(update_fields=['status', 'updated_at'])
        kitchen_order.save(update_fields=['preparation_start_time', 'updated_at'])
        return Response(self.get_serializer(kitchen_order).data)

    @action(detail=True, methods=['post'])
    def mark_ready(self, request, pk=None):
        """Mark the order as ready for delivery."""
        kitchen_order = self.get_object()
        kitchen_order.preparation_end_time = timezone.now()
        kitchen_order.order.status = 'ready'
        kitchen_order.order.save(update_fields=['status', 'updated_at'])
        kitchen_order.save(update_fields=['preparation_end_time', 'updated_at'])
        
        # Create Delivery with auto-assigned driver
        from apps.delivery.models import Delivery
        from apps.main.utils.delivery_utils import assign_driver_to_order
        
        assigned_driver = assign_driver_to_order(kitchen_order.order)
        delivery, created = Delivery.objects.get_or_create(
            order=kitchen_order.order,
            defaults={
                'status': 'pending',
                'driver': assigned_driver
            }
        )
        if not delivery.driver and assigned_driver:
            delivery.driver = assigned_driver
            delivery.save(update_fields=['driver'])
        
        return Response(self.get_serializer(kitchen_order).data) 