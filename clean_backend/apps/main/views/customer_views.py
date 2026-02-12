from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from apps.main.models import Subscription, WalletTransaction, Address, MenuItem
from apps.main.serializers.customer_serializers import (
    SubscriptionSerializer,
    WalletTransactionSerializer,
    AddressSerializer,
    MenuItemSerializer,
)


class CustomerBaseViewSet(viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if hasattr(self.request.user, 'customerprofile'):
            return self.queryset.filter(customer=self.request.user.customerprofile)
        return self.queryset.none()


class MenuItemViewSet(viewsets.ModelViewSet):
    """
    API endpoint for managing menu items.
    Staff users can create/update/delete. Authenticated users can list/retrieve.
    """
    queryset = MenuItem.objects.select_related('category', 'inventory_item').all()
    serializer_class = MenuItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['is_available', 'category']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'price', 'created_at']

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]

    @action(detail=True, methods=['post'])
    def toggle_availability(self, request, pk=None):
        """Toggle the is_available status of a menu item."""
        item = self.get_object()
        item.is_available = not item.is_available
        item.save(update_fields=['is_available', 'updated_at'])
        return Response(self.get_serializer(item).data)


class SubscriptionViewSet(CustomerBaseViewSet, viewsets.ReadOnlyModelViewSet):
    queryset = Subscription.objects.all()
    serializer_class = SubscriptionSerializer


class WalletTransactionViewSet(CustomerBaseViewSet, viewsets.ReadOnlyModelViewSet):
    queryset = WalletTransaction.objects.all()
    serializer_class = WalletTransactionSerializer


class AddressViewSet(CustomerBaseViewSet, viewsets.ModelViewSet):
    queryset = Address.objects.all()
    serializer_class = AddressSerializer

    def perform_create(self, serializer):
        if hasattr(self.request.user, 'customerprofile'):
            serializer.save(customer=self.request.user.customerprofile)
