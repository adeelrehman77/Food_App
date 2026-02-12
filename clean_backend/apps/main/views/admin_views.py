"""
Tenant-admin facing ViewSets.
These power the Flutter admin dashboard for kitchen staff, managers, and admins.
"""
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.contrib.auth.models import User, Group
from django.utils import timezone

from apps.main.models import (
    Order, CustomerProfile, Invoice, Notification,
    CustomerRegistrationRequest, Category,
)
from apps.main.serializers.admin_serializers import (
    OrderListSerializer, OrderDetailSerializer, OrderStatusUpdateSerializer,
    CustomerProfileAdminSerializer, CustomerRegistrationRequestSerializer,
    InvoiceSerializer, NotificationSerializer, CategorySerializer,
    StaffUserSerializer, StaffUserCreateSerializer,
)
from core.permissions.plan_limits import PlanLimitStaffUsers


# ─── Orders ────────────────────────────────────────────────────────────────────

class OrderViewSet(viewsets.ModelViewSet):
    """
    Manage orders within the tenant. Staff can list all orders;
    update status, cancel, etc.
    """
    queryset = Order.objects.select_related(
        'subscription__customer__user',
    ).all()
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['status', 'order_date', 'delivery_date']
    search_fields = [
        'subscription__customer__user__username',
        'subscription__customer__phone',
    ]
    ordering_fields = ['order_date', 'delivery_date', 'status', 'created_at']
    ordering = ['-delivery_date']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return OrderDetailSerializer
        return OrderListSerializer

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        """Update order status with validation."""
        order = self.get_object()
        serializer = OrderStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']
        valid_transitions = {
            'pending': ['confirmed', 'cancelled'],
            'confirmed': ['preparing', 'cancelled'],
            'preparing': ['ready', 'cancelled'],
            'ready': ['delivered'],
            'delivered': [],
            'cancelled': [],
        }

        if new_status not in valid_transitions.get(order.status, []):
            return Response(
                {'error': f"Cannot transition from '{order.status}' to '{new_status}'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.status = new_status
        order.save(update_fields=['status', 'updated_at'])
        return Response(OrderDetailSerializer(order).data)


# ─── Customer Management ──────────────────────────────────────────────────────

class CustomerProfileViewSet(viewsets.ModelViewSet):
    """View and manage customer profiles within the tenant."""
    queryset = CustomerProfile.objects.select_related('user').all()
    serializer_class = CustomerProfileAdminSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['loyalty_tier', 'preferred_communication']
    search_fields = ['user__username', 'user__email', 'name', 'phone']
    ordering_fields = ['created_at', 'wallet_balance', 'loyalty_points']


class CustomerRegistrationRequestViewSet(viewsets.ModelViewSet):
    """Manage customer registration requests (approve/reject)."""
    queryset = CustomerRegistrationRequest.objects.all()
    serializer_class = CustomerRegistrationRequestSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['status']
    ordering = ['-created_at']

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        obj = self.get_object()
        if obj.status != 'pending':
            return Response(
                {'error': 'Only pending requests can be approved.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        obj.status = 'approved'
        obj.processed_at = timezone.now()
        obj.processed_by = request.user
        obj.save()
        return Response(self.get_serializer(obj).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        obj = self.get_object()
        if obj.status != 'pending':
            return Response(
                {'error': 'Only pending requests can be rejected.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        obj.status = 'rejected'
        obj.rejection_reason = request.data.get('reason', '')
        obj.processed_at = timezone.now()
        obj.processed_by = request.user
        obj.save()
        return Response(self.get_serializer(obj).data)


# ─── Invoices ──────────────────────────────────────────────────────────────────

class InvoiceViewSet(viewsets.ReadOnlyModelViewSet):
    """View invoices. Admins can see all; filtering by customer and status."""
    queryset = Invoice.objects.select_related('customer__user').prefetch_related('items__menu').all()
    serializer_class = InvoiceSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['status', 'customer']
    ordering = ['-date']


# ─── Notifications ─────────────────────────────────────────────────────────────

class NotificationViewSet(viewsets.ModelViewSet):
    """Manage notifications for customers."""
    queryset = Notification.objects.select_related('customer').all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['priority', 'read', 'customer']
    ordering = ['-created_at']


# ─── Categories ────────────────────────────────────────────────────────────────

class CategoryViewSet(viewsets.ModelViewSet):
    """Manage food categories."""
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy'):
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]


# ─── Staff User Management ─────────────────────────────────────────────────────

class StaffUserViewSet(viewsets.ModelViewSet):
    """
    Manage staff users within the tenant.
    Tenant admins can invite, list, deactivate staff and assign roles.
    """
    queryset = User.objects.prefetch_related('groups').filter(is_active=True)
    serializer_class = StaffUserSerializer
    permission_classes = [permissions.IsAdminUser, PlanLimitStaffUsers]
    search_fields = ['username', 'email', 'first_name', 'last_name']
    ordering = ['-date_joined']

    def get_serializer_class(self):
        if self.action == 'create':
            return StaffUserCreateSerializer
        return StaffUserSerializer

    def create(self, request, *args, **kwargs):
        """Create a new staff user and assign role."""
        serializer = StaffUserCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if User.objects.filter(username=data['username']).exists():
            return Response(
                {'error': 'Username already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.create_user(
            username=data['username'],
            email=data['email'],
            password=data['password'],
            first_name=data.get('first_name', ''),
            last_name=data.get('last_name', ''),
            is_staff=True,
        )

        # Assign role via Django groups
        role = data.get('role', 'staff')
        role_group_map = {
            'manager': 'Manager',
            'kitchen_staff': 'Kitchen Staff',
            'driver': 'Driver',
        }
        if role in role_group_map:
            group, _ = Group.objects.get_or_create(name=role_group_map[role])
            user.groups.add(group)

        return Response(
            StaffUserSerializer(user).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=['post'])
    def deactivate(self, request, pk=None):
        """Deactivate a staff user."""
        user = self.get_object()
        if user == request.user:
            return Response(
                {'error': 'You cannot deactivate yourself.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.is_active = False
        user.save(update_fields=['is_active'])
        return Response({'status': 'User deactivated.'})

    @action(detail=True, methods=['post'])
    def change_role(self, request, pk=None):
        """Change the role of a staff user."""
        user = self.get_object()
        new_role = request.data.get('role')
        if new_role not in ('manager', 'kitchen_staff', 'driver', 'staff'):
            return Response(
                {'error': 'Invalid role.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Clear existing role groups
        user.groups.clear()

        role_group_map = {
            'manager': 'Manager',
            'kitchen_staff': 'Kitchen Staff',
            'driver': 'Driver',
        }
        if new_role in role_group_map:
            group, _ = Group.objects.get_or_create(name=role_group_map[new_role])
            user.groups.add(group)

        return Response(StaffUserSerializer(user).data)
