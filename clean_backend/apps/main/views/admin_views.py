"""
Tenant-admin facing ViewSets.
These power the Flutter admin dashboard for kitchen staff, managers, and admins.
"""
import datetime

from django.db.models import Sum, Count, Q
from rest_framework import viewsets, permissions, status, filters
from rest_framework.decorators import api_view, permission_classes as perm_classes
from rest_framework.response import Response
from rest_framework.decorators import action
from django.contrib.auth.models import User, Group
from django.utils import timezone

from apps.main.models import (
    Order, CustomerProfile, Invoice, Notification,
    CustomerRegistrationRequest, Category, Subscription,
    MealSlot, DailyMenu, MealPackage,
)
from apps.main.serializers.admin_serializers import (
    OrderListSerializer, OrderDetailSerializer, OrderStatusUpdateSerializer,
    CustomerProfileAdminSerializer, CustomerRegistrationRequestSerializer,
    InvoiceSerializer, NotificationSerializer, CategorySerializer,
    StaffUserSerializer, StaffUserCreateSerializer,
    MealSlotSerializer,
    DailyMenuListSerializer, DailyMenuDetailSerializer, DailyMenuCreateSerializer,
    MealPackageSerializer,
)
from apps.users.models import UserProfile
from core.permissions.plan_limits import PlanLimitStaffUsers


# ─── Dashboard Summary ─────────────────────────────────────────────────────────

@api_view(['GET'])
@perm_classes([permissions.IsAuthenticated])
def dashboard_summary(request):
    """
    Aggregated dashboard summary for tenant admin overview.
    Returns key metrics: orders, customers, revenue, deliveries, etc.
    """
    today = timezone.now().date()
    first_of_month = today.replace(day=1)

    # ── Orders ──
    total_orders = Order.objects.count()
    orders_today = Order.objects.filter(delivery_date=today).count()
    pending_orders = Order.objects.filter(status='pending').count()
    preparing_orders = Order.objects.filter(status='preparing').count()

    # ── Customers ──
    total_customers = CustomerProfile.objects.count()
    active_subscriptions = Subscription.objects.filter(status='active').count()
    pending_registrations = CustomerRegistrationRequest.objects.filter(
        status='pending'
    ).count()

    # ── Revenue (current month) ──
    monthly_revenue = Invoice.objects.filter(
        date__gte=first_of_month, status='paid',
    ).aggregate(total=Sum('total'))['total'] or 0

    pending_invoices = Invoice.objects.filter(status='pending').count()
    overdue_invoices = Invoice.objects.filter(
        status='pending', due_date__lt=today,
    ).count()

    # ── Staff ──
    total_staff = User.objects.filter(is_staff=True, is_active=True).count()

    # ── Inventory (low-stock) ──
    try:
        from apps.inventory.models import InventoryItem
        from django.db import models as db_models
        low_stock_count = InventoryItem.objects.filter(
            is_active=True,
            current_stock__lte=db_models.F('min_stock_level'),
        ).count()
    except Exception:
        low_stock_count = 0

    # ── Deliveries today ──
    try:
        from apps.delivery.models import Delivery
        deliveries_today = Delivery.objects.filter(
            order__delivery_date=today,
        ).count()
        completed_deliveries = Delivery.objects.filter(
            order__delivery_date=today, status='delivered',
        ).count()
    except Exception:
        deliveries_today = 0
        completed_deliveries = 0

    # ── Recent orders (last 5) ──
    recent_orders = Order.objects.select_related(
        'subscription__customer__user',
    ).order_by('-created_at')[:5]
    recent_orders_data = OrderListSerializer(recent_orders, many=True).data

    return Response({
        'orders': {
            'total': total_orders,
            'today': orders_today,
            'pending': pending_orders,
            'preparing': preparing_orders,
        },
        'customers': {
            'total': total_customers,
            'active_subscriptions': active_subscriptions,
            'pending_registrations': pending_registrations,
        },
        'revenue': {
            'monthly': float(monthly_revenue),
            'pending_invoices': pending_invoices,
            'overdue_invoices': overdue_invoices,
        },
        'staff': {
            'total': total_staff,
        },
        'inventory': {
            'low_stock_count': low_stock_count,
        },
        'deliveries': {
            'today': deliveries_today,
            'completed': completed_deliveries,
        },
        'recent_orders': recent_orders_data,
    })


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

    Only users whose UserProfile.tenant matches request.tenant are shown.
    """
    serializer_class = StaffUserSerializer
    permission_classes = [permissions.IsAdminUser, PlanLimitStaffUsers]
    search_fields = ['username', 'email', 'first_name', 'last_name']
    ordering = ['-date_joined']

    def get_queryset(self):
        qs = User.objects.prefetch_related('groups').filter(is_active=True)
        tenant = getattr(self.request, 'tenant', None)
        if tenant:
            qs = qs.filter(userprofile__tenant=tenant)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return StaffUserCreateSerializer
        return StaffUserSerializer

    def create(self, request, *args, **kwargs):
        """Create a new staff user, assign role, and link to current tenant."""
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

        # Link user to the current tenant via UserProfile
        tenant = getattr(request, 'tenant', None)
        UserProfile.objects.update_or_create(
            user=user,
            defaults={'tenant': tenant},
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


# ─── Meal Slots ───────────────────────────────────────────────────────────────

class MealSlotViewSet(viewsets.ModelViewSet):
    """
    CRUD for meal slots (Lunch, Dinner, Breakfast, etc.).
    Read access for all authenticated users; write access for admins.
    """
    queryset = MealSlot.objects.all()
    serializer_class = MealSlotSerializer
    permission_classes = [permissions.IsAuthenticated]
    search_fields = ['name', 'code']
    ordering = ['sort_order']

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy'):
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]


# ─── Daily Menus ──────────────────────────────────────────────────────────────

class DailyMenuViewSet(viewsets.ModelViewSet):
    """
    Manage daily menus.

    List supports filtering by:
        - date_from / date_to (query params)
        - meal_slot (query param, id)
        - status (query param)

    Custom actions:
        - POST  /{id}/publish/   →  status = published
        - POST  /{id}/close/     →  status = closed
        - GET   /today/          →  today's published menus
        - GET   /week/           →  current (or specified) week's menus
    """
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['notes']
    ordering_fields = ['menu_date', 'status', 'created_at']
    ordering = ['menu_date']

    def get_queryset(self):
        qs = DailyMenu.objects.select_related('meal_slot', 'created_by').prefetch_related(
            'items__master_item__category',
        ).annotate(item_count=Count('items'))

        # ── Filters via query params ──
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        meal_slot = self.request.query_params.get('meal_slot')
        menu_status = self.request.query_params.get('status')
        diet_type = self.request.query_params.get('diet_type')

        if date_from:
            qs = qs.filter(menu_date__gte=date_from)
        if date_to:
            qs = qs.filter(menu_date__lte=date_to)
        if meal_slot:
            qs = qs.filter(meal_slot_id=meal_slot)
        if menu_status:
            qs = qs.filter(status=menu_status)
        if diet_type:
            qs = qs.filter(diet_type=diet_type)

        return qs

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update'):
            return DailyMenuCreateSerializer
        if self.action == 'retrieve':
            return DailyMenuDetailSerializer
        return DailyMenuListSerializer

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy',
                           'publish', 'close'):
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]

    # ── Custom Actions ────────────────────────────────────────────────────────

    @action(detail=True, methods=['post'])
    def publish(self, request, pk=None):
        """Transition a daily menu from draft → published."""
        menu = self.get_object()
        if menu.status == 'published':
            return Response({'detail': 'Already published.'})
        if menu.status == 'closed':
            return Response(
                {'error': 'Cannot publish a closed menu.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not menu.items.exists():
            return Response(
                {'error': 'Cannot publish an empty menu — add items first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        menu.status = 'published'
        menu.save(update_fields=['status', 'updated_at'])
        return Response(DailyMenuDetailSerializer(
            self.get_queryset().get(pk=menu.pk),
            context={'request': request},
        ).data)

    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        """Transition a daily menu → closed."""
        menu = self.get_object()
        if menu.status == 'closed':
            return Response({'detail': 'Already closed.'})
        menu.status = 'closed'
        menu.save(update_fields=['status', 'updated_at'])
        return Response(DailyMenuDetailSerializer(
            self.get_queryset().get(pk=menu.pk),
            context={'request': request},
        ).data)

    @action(detail=False, methods=['get'])
    def today(self, request):
        """Return today's published menus (for customer facing views)."""
        today = timezone.now().date()
        qs = self.get_queryset().filter(menu_date=today, status='published')
        serializer = DailyMenuDetailSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def week(self, request):
        """
        Return a week's menus (all statuses).
        Query param: ?start=2026-02-10  (defaults to current week's Monday)
        """
        start_param = request.query_params.get('start')
        if start_param:
            try:
                start = datetime.date.fromisoformat(start_param)
            except ValueError:
                return Response(
                    {'error': 'Invalid date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        else:
            today = timezone.now().date()
            start = today - datetime.timedelta(days=today.weekday())  # Monday

        end = start + datetime.timedelta(days=6)  # Sunday
        qs = self.get_queryset().filter(menu_date__gte=start, menu_date__lte=end)
        serializer = DailyMenuListSerializer(qs, many=True, context={'request': request})
        return Response({
            'week_start': start.isoformat(),
            'week_end': end.isoformat(),
            'menus': serializer.data,
        })


# ─── Meal Packages ────────────────────────────────────────────────────────────

class MealPackageViewSet(viewsets.ModelViewSet):
    """
    CRUD for tenant-defined meal packages / subscription tiers.
    Tenants create their own package names, prices, and configurations.
    """
    queryset = MealPackage.objects.all()
    serializer_class = MealPackageSerializer
    permission_classes = [permissions.IsAuthenticated]
    search_fields = ['name', 'description']
    filterset_fields = ['diet_type', 'duration', 'is_active']
    ordering = ['sort_order', 'name']

    def get_permissions(self):
        if self.action in ('create', 'update', 'partial_update', 'destroy'):
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]
