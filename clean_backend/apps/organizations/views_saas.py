"""
SaaS Owner (Layer 1) API views.

These endpoints are for the platform admin / SaaS owner to:
- Manage tenants (provision, activate, suspend, change plan)
- Manage service plans
- View billing / invoices
- View usage metrics and platform analytics

Access: Superuser only (platform admin).
"""
import secrets
from decimal import Decimal
from datetime import timedelta

from django.contrib.auth.models import User
from django.db.models import Count, Sum, Q
from django.utils import timezone
from rest_framework import viewsets, permissions, status as drf_status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from apps.users.models import Tenant
from apps.organizations.models import ServicePlan
from apps.organizations.models_saas import (
    TenantSubscription, TenantInvoice, TenantUsage,
)
from apps.organizations.serializers import (
    ServicePlanSerializer, TenantListSerializer, TenantDetailSerializer,
    TenantCreateSerializer, TenantUpdateSerializer,
    TenantSubscriptionSerializer, TenantInvoiceSerializer,
    TenantUsageSerializer, PlatformAnalyticsSerializer,
)


class IsSuperUser(permissions.BasePermission):
    """Only allow superusers (platform admins)."""
    def has_permission(self, request, view):
        return request.user and request.user.is_superuser


# ─── Service Plans ─────────────────────────────────────────────────────────────

class ServicePlanViewSet(viewsets.ModelViewSet):
    """
    CRUD for service plans.
    Only superusers can manage plans.
    """
    queryset = ServicePlan.objects.annotate(
        tenant_count=Count('tenant_subscriptions'),
    ).all()
    serializer_class = ServicePlanSerializer
    permission_classes = [IsSuperUser]
    filterset_fields = ['tier', 'is_active']
    search_fields = ['name', 'description']
    ordering = ['price_monthly']


# ─── Tenants ───────────────────────────────────────────────────────────────────

class TenantViewSet(viewsets.ModelViewSet):
    """
    Manage tenants (kitchens) on the platform.

    - List all tenants with status
    - Create / provision new tenant
    - Update settings, activate, suspend
    - View usage metrics
    """
    queryset = Tenant.objects.select_related('service_plan').all()
    permission_classes = [IsSuperUser]
    filterset_fields = ['is_active']
    search_fields = ['name', 'subdomain']
    ordering = ['-created_on']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return TenantDetailSerializer
        if self.action == 'create':
            return TenantCreateSerializer
        if self.action in ('update', 'partial_update'):
            return TenantUpdateSerializer
        return TenantListSerializer

    def create(self, request, *args, **kwargs):
        """
        Provision a new tenant.
        Creates: tenant record, admin user, and subscription (if plan provided).
        Note: Actual database provisioning would be handled by a Celery task
        or management command in production.
        """
        serializer = TenantCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Create tenant
        tenant = Tenant.objects.create(
            name=data['name'],
            subdomain=data['subdomain'],
            schema_name=data['subdomain'],
            db_name=f"tenant_{data['subdomain']}",
            is_active=True,
        )

        # ── Create tenant admin user ──
        admin_email = data.get('admin_email', '')
        admin_password = data.get('admin_password') or secrets.token_urlsafe(12)
        # Use email prefix as username, ensuring uniqueness
        base_username = admin_email.split('@')[0] if admin_email else data['subdomain']
        username = base_username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}{counter}"
            counter += 1

        admin_user = User.objects.create_user(
            username=username,
            email=admin_email,
            password=admin_password,
            is_staff=True,   # Gives access to tenant admin dashboard
            is_active=True,
        )

        # Store admin info in response for the SaaS owner to share
        admin_info = {
            'admin_username': username,
            'admin_email': admin_email,
            'admin_password_was_generated': 'admin_password' not in data or not data.get('admin_password'),
        }

        # Assign plan and create subscription
        plan_id = data.get('plan_id')
        if plan_id:
            try:
                plan = ServicePlan.objects.get(id=plan_id, is_active=True)
                tenant.service_plan = plan
                tenant.save(update_fields=['service_plan'])

                now = timezone.now().date()
                TenantSubscription.objects.create(
                    tenant=tenant,
                    plan=plan,
                    status='trial',
                    billing_cycle='monthly',
                    current_period_start=now,
                    current_period_end=now + timedelta(days=plan.trial_days),
                    trial_end=now + timedelta(days=plan.trial_days),
                    next_invoice_date=now + timedelta(days=plan.trial_days),
                )
            except ServicePlan.DoesNotExist:
                pass

        response_data = TenantDetailSerializer(tenant).data
        response_data['admin_info'] = admin_info

        return Response(
            response_data,
            status=drf_status.HTTP_201_CREATED,
        )

    def update(self, request, *args, **kwargs):
        tenant = self.get_object()
        serializer = TenantUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if 'name' in data:
            tenant.name = data['name']
        if 'is_active' in data:
            tenant.is_active = data['is_active']
        if 'plan_id' in data:
            try:
                plan = ServicePlan.objects.get(id=data['plan_id'])
                tenant.service_plan = plan
            except ServicePlan.DoesNotExist:
                return Response(
                    {'error': 'Plan not found.'},
                    status=drf_status.HTTP_400_BAD_REQUEST,
                )

        tenant.save()
        return Response(TenantDetailSerializer(tenant).data)

    @action(detail=True, methods=['get'])
    def usage(self, request, pk=None):
        """Get usage metrics for a specific tenant."""
        tenant = self.get_object()
        usage_records = TenantUsage.objects.filter(tenant=tenant)[:12]
        serializer = TenantUsageSerializer(usage_records, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        """Suspend a tenant."""
        tenant = self.get_object()
        tenant.is_active = False
        tenant.save(update_fields=['is_active'])

        sub = getattr(tenant, 'subscription', None)
        if sub:
            sub.status = 'suspended'
            sub.save(update_fields=['status', 'updated_at'])

        return Response({'status': 'Tenant suspended.'})

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        """Activate a suspended tenant."""
        tenant = self.get_object()
        tenant.is_active = True
        tenant.save(update_fields=['is_active'])

        sub = getattr(tenant, 'subscription', None)
        if sub and sub.status == 'suspended':
            sub.status = 'active'
            sub.save(update_fields=['status', 'updated_at'])

        return Response({'status': 'Tenant activated.'})


# ─── Tenant Subscriptions ─────────────────────────────────────────────────────

class TenantSubscriptionViewSet(viewsets.ModelViewSet):
    """Manage tenant subscriptions."""
    queryset = TenantSubscription.objects.select_related('tenant', 'plan').all()
    serializer_class = TenantSubscriptionSerializer
    permission_classes = [IsSuperUser]
    filterset_fields = ['status', 'billing_cycle', 'plan']
    ordering = ['-created_at']


# ─── Tenant Invoices ──────────────────────────────────────────────────────────

class TenantInvoiceViewSet(viewsets.ModelViewSet):
    """Manage tenant invoices / billing."""
    queryset = TenantInvoice.objects.select_related('tenant', 'subscription').all()
    serializer_class = TenantInvoiceSerializer
    permission_classes = [IsSuperUser]
    filterset_fields = ['status', 'tenant']
    ordering = ['-created_at']

    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        invoice = self.get_object()
        invoice.status = 'paid'
        invoice.paid_at = timezone.now()
        invoice.save(update_fields=['status', 'paid_at'])
        return Response(TenantInvoiceSerializer(invoice).data)


# ─── Platform Analytics ───────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsSuperUser])
def platform_analytics(request):
    """
    Aggregated platform-wide metrics for the SaaS owner dashboard.
    """
    total_tenants = Tenant.objects.count()
    active_tenants = Tenant.objects.filter(is_active=True).count()
    trial_tenants = TenantSubscription.objects.filter(status='trial').count()

    # Revenue from subscriptions
    active_subs = TenantSubscription.objects.filter(status='active')
    monthly_rev = active_subs.filter(billing_cycle='monthly').aggregate(
        total=Sum('plan__price_monthly'),
    )['total'] or Decimal('0.00')
    yearly_rev = active_subs.filter(billing_cycle='yearly').aggregate(
        total=Sum('plan__price_yearly'),
    )['total'] or Decimal('0.00')

    pending = TenantInvoice.objects.filter(status='pending').count()
    overdue = TenantInvoice.objects.filter(status='overdue').count()

    data = {
        'total_tenants': total_tenants,
        'active_tenants': active_tenants,
        'trial_tenants': trial_tenants,
        'total_revenue_monthly': monthly_rev,
        'total_revenue_yearly': yearly_rev,
        'pending_invoices': pending,
        'overdue_invoices': overdue,
    }

    serializer = PlatformAnalyticsSerializer(data)
    return Response(serializer.data)
