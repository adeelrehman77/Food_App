from rest_framework import viewsets, permissions
from apps.main.models import Subscription, WalletTransaction, Address
from apps.main.serializers.customer_serializers import (
    SubscriptionSerializer, 
    WalletTransactionSerializer, 
    AddressSerializer
)

class CustomerBaseViewSet(viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Ensure user has a customer profile
        if hasattr(self.request.user, 'customerprofile'):
            return self.queryset.filter(customer=self.request.user.customerprofile)
        return self.queryset.none()

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
