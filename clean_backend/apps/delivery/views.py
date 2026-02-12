from django.shortcuts import render
from django.http import JsonResponse
from rest_framework import viewsets, permissions
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
    queryset = Delivery.objects.select_related('order', 'driver').all()
    serializer_class = DeliverySerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['status', 'driver']
    ordering = ['-created_at']
    search_fields = ['order__id', 'driver__username']
