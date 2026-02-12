"""
Customer-facing API (Layer 3: B2C).

These endpoints are used by the customer mobile app or web portal.
They provide:
- Customer self-registration and authentication
- Public menu browsing (no auth required)
- Subscription management
- Order history and tracking
- Wallet operations
- Profile management
- Notification management
"""
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone
from rest_framework import viewsets, permissions, status as drf_status, generics
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from apps.main.models import (
    MenuItem, Category, CustomerProfile, Subscription,
    Order, WalletTransaction, Invoice, Notification, Address,
    CustomerRegistrationRequest,
)
from apps.main.serializers.customer_serializers import (
    MenuItemSerializer, SubscriptionSerializer,
    WalletTransactionSerializer, AddressSerializer,
)
from apps.main.serializers.customer_api_serializers import (
    CustomerRegisterSerializer, CustomerLoginSerializer,
    CustomerProfileSerializer, PublicMenuItemSerializer,
    PublicCategorySerializer, CustomerOrderSerializer,
    CustomerInvoiceSerializer, CustomerNotificationSerializer,
    WalletTopUpSerializer,
)


# ─── Authentication ────────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def customer_register(request):
    """
    Register a new customer account.
    Creates a Django User + CustomerProfile.
    """
    serializer = CustomerRegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    if User.objects.filter(username=data['phone']).exists():
        return Response(
            {'error': 'An account with this phone number already exists.'},
            status=drf_status.HTTP_400_BAD_REQUEST,
        )

    if data.get('email') and User.objects.filter(email=data['email']).exists():
        return Response(
            {'error': 'An account with this email already exists.'},
            status=drf_status.HTTP_400_BAD_REQUEST,
        )

    # Create User (username = phone number for customers)
    user = User.objects.create_user(
        username=data['phone'],
        email=data.get('email', ''),
        password=data['password'],
        first_name=data.get('first_name', ''),
        last_name=data.get('last_name', ''),
    )

    # Create CustomerProfile
    tenant = getattr(request, 'tenant', None)
    profile = CustomerProfile.objects.create(
        user=user,
        tenant_id=tenant.id if tenant else None,
        name=f"{data.get('first_name', '')} {data.get('last_name', '')}".strip(),
        phone=data['phone'],
    )

    # Generate JWT tokens
    refresh = RefreshToken.for_user(user)

    return Response({
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'name': profile.name,
            'phone': profile.phone,
        },
        'tokens': {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        },
    }, status=drf_status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def customer_login(request):
    """
    Customer login via phone + password.
    Returns JWT tokens.
    """
    serializer = CustomerLoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    user = authenticate(
        username=data['phone'],
        password=data['password'],
    )

    if user is None:
        return Response(
            {'error': 'Invalid phone number or password.'},
            status=drf_status.HTTP_401_UNAUTHORIZED,
        )

    if not user.is_active:
        return Response(
            {'error': 'Account is deactivated.'},
            status=drf_status.HTTP_403_FORBIDDEN,
        )

    refresh = RefreshToken.for_user(user)

    # Get profile
    profile = getattr(user, 'customerprofile', None)
    return Response({
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'name': profile.name if profile else user.get_full_name(),
            'phone': profile.phone if profile else '',
        },
        'tokens': {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        },
    })


# ─── Public Menu Browsing (no auth) ───────────────────────────────────────────

@api_view(['GET'])
@permission_classes([AllowAny])
def public_menu(request):
    """
    Browse available menu items for this tenant. No authentication required.
    Supports filtering by category.
    """
    items = MenuItem.objects.filter(is_available=True).select_related('category')

    category_id = request.query_params.get('category')
    if category_id:
        items = items.filter(category_id=category_id)

    search = request.query_params.get('search')
    if search:
        items = items.filter(
            Q(name__icontains=search) | Q(description__icontains=search)
        )

    serializer = PublicMenuItemSerializer(items, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([AllowAny])
def public_categories(request):
    """List all menu categories for the tenant."""
    categories = Category.objects.all()
    serializer = PublicCategorySerializer(categories, many=True)
    return Response(serializer.data)


# ─── Customer Profile ─────────────────────────────────────────────────────────

class CustomerProfileView(generics.RetrieveUpdateAPIView):
    """Get and update the authenticated customer's profile."""
    serializer_class = CustomerProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.customerprofile


# ─── Customer Subscriptions ───────────────────────────────────────────────────

class CustomerSubscriptionViewSet(viewsets.ModelViewSet):
    """
    Customers can view their subscriptions and create new ones.
    """
    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Subscription.objects.filter(
            customer__user=self.request.user,
        ).select_related('time_slot', 'customer').prefetch_related('menus')

    def perform_create(self, serializer):
        profile = self.request.user.customerprofile
        serializer.save(customer=profile)


# ─── Customer Orders ──────────────────────────────────────────────────────────

class CustomerOrderViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Customers can view their orders and track delivery.
    """
    serializer_class = CustomerOrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(
            subscription__customer__user=self.request.user,
        ).select_related('subscription').order_by('-delivery_date')

    @action(detail=True, methods=['get'])
    def track(self, request, pk=None):
        """Get delivery tracking info for an order."""
        order = self.get_object()
        # Check if there's a delivery associated
        delivery = getattr(order, 'delivery', None)
        if delivery:
            return Response({
                'order_id': order.id,
                'order_status': order.status,
                'delivery_status': delivery.status,
                'pickup_time': delivery.pickup_time,
                'delivery_time': delivery.delivery_time,
                'notes': delivery.notes,
            })
        return Response({
            'order_id': order.id,
            'order_status': order.status,
            'delivery_status': None,
            'message': 'No delivery tracking available yet.',
        })


# ─── Customer Wallet ──────────────────────────────────────────────────────────

class CustomerWalletViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Customers can view their wallet balance and transaction history.
    """
    serializer_class = WalletTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return WalletTransaction.objects.filter(
            customer__user=self.request.user,
        ).order_by('-created_at')

    def list(self, request, *args, **kwargs):
        """Return balance + recent transactions."""
        profile = request.user.customerprofile
        response = super().list(request, *args, **kwargs)
        response.data = {
            'balance': str(profile.wallet_balance),
            'transactions': response.data,
        }
        return response

    @action(detail=False, methods=['post'])
    def topup(self, request):
        """Add funds to wallet (placeholder — would integrate with payment gateway)."""
        serializer = WalletTopUpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        amount = serializer.validated_data['amount']
        profile = request.user.customerprofile
        profile.wallet_balance += amount
        profile.save(update_fields=['wallet_balance'])

        WalletTransaction.objects.create(
            customer=profile,
            amount=amount,
            transaction_type='credit',
            description=f'Wallet top-up of {amount}',
        )

        return Response({
            'balance': str(profile.wallet_balance),
            'message': f'Successfully added {amount} to wallet.',
        })


# ─── Customer Invoices ────────────────────────────────────────────────────────

class CustomerInvoiceViewSet(viewsets.ReadOnlyModelViewSet):
    """Customers can view their invoices."""
    serializer_class = CustomerInvoiceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Invoice.objects.filter(
            customer__user=self.request.user,
        ).order_by('-date')


# ─── Customer Notifications ───────────────────────────────────────────────────

class CustomerNotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """Customers can view and mark their notifications as read."""
    serializer_class = CustomerNotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(
            customer__user=self.request.user,
        ).order_by('-created_at')

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """Mark a notification as read."""
        notification = self.get_object()
        notification.read = True
        notification.read_at = timezone.now()
        notification.save(update_fields=['read', 'read_at'])
        return Response({'status': 'marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        """Mark all notifications as read."""
        self.get_queryset().filter(read=False).update(
            read=True, read_at=timezone.now(),
        )
        return Response({'status': 'all marked as read'})


# ─── Customer Addresses ───────────────────────────────────────────────────────

class CustomerAddressViewSet(viewsets.ModelViewSet):
    """Customers can manage their delivery addresses."""
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Address.objects.filter(customer__user=self.request.user)

    def perform_create(self, serializer):
        profile = self.request.user.customerprofile
        serializer.save(customer=profile)
