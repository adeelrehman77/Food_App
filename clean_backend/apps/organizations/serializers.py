"""
SaaS Owner (Layer 1) serializers.
Used by the platform admin dashboard.
"""
from rest_framework import serializers
from apps.users.models import Tenant
from apps.organizations.models import ServicePlan
from apps.organizations.models_saas import (
    TenantSubscription, TenantInvoice, TenantUsage,
)


# ─── Service Plans ─────────────────────────────────────────────────────────────

class ServicePlanSerializer(serializers.ModelSerializer):
    tenant_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = ServicePlan
        fields = [
            'id', 'name', 'tier', 'description',
            'price_monthly', 'price_yearly', 'trial_days',
            'max_menu_items', 'max_staff_users',
            'max_customers', 'max_orders_per_month',
            'has_inventory_management', 'has_delivery_tracking',
            'has_customer_app', 'has_analytics',
            'has_whatsapp_notifications', 'has_multi_branch',
            'features', 'is_active', 'tenant_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


# ─── Tenants ───────────────────────────────────────────────────────────────────

class TenantListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for tenant list view."""
    plan_name = serializers.CharField(
        source='service_plan.name', read_only=True, default='No Plan',
    )
    subscription_status = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = [
            'id', 'name', 'subdomain', 'is_active',
            'plan_name', 'subscription_status',
            'created_on',
        ]

    def get_subscription_status(self, obj):
        sub = getattr(obj, 'subscription', None)
        if sub:
            return sub.get_status_display()
        return 'No Subscription'


class TenantDetailSerializer(serializers.ModelSerializer):
    """Full tenant detail with subscription and usage info."""
    service_plan = ServicePlanSerializer(read_only=True)
    subscription = serializers.SerializerMethodField()
    latest_usage = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = [
            'id', 'name', 'subdomain', 'schema_name',
            'db_name', 'db_host', 'db_port',
            'is_active', 'service_plan',
            'subscription', 'latest_usage',
            'created_on',
        ]

    def get_subscription(self, obj):
        sub = getattr(obj, 'subscription', None)
        if sub:
            return TenantSubscriptionSerializer(sub).data
        return None

    def get_latest_usage(self, obj):
        usage = obj.usage_records.first()
        if usage:
            return TenantUsageSerializer(usage).data
        return None


class TenantCreateSerializer(serializers.Serializer):
    """For provisioning a new tenant."""
    name = serializers.CharField(max_length=100)
    subdomain = serializers.CharField(max_length=100)
    plan_id = serializers.IntegerField(required=False)
    admin_email = serializers.EmailField()
    admin_password = serializers.CharField(write_only=True, min_length=8, required=False)

    def validate_subdomain(self, value):
        if Tenant.objects.filter(subdomain__iexact=value).exists():
            raise serializers.ValidationError("Subdomain already taken.")
        return value.lower()


class TenantUpdateSerializer(serializers.Serializer):
    """For updating tenant settings."""
    name = serializers.CharField(max_length=100, required=False)
    is_active = serializers.BooleanField(required=False)
    plan_id = serializers.IntegerField(required=False)


# ─── Tenant Subscriptions ─────────────────────────────────────────────────────

class TenantSubscriptionSerializer(serializers.ModelSerializer):
    plan_name = serializers.CharField(source='plan.name', read_only=True)
    tenant_name = serializers.CharField(source='tenant.name', read_only=True)
    current_price = serializers.DecimalField(
        max_digits=10, decimal_places=2, read_only=True,
    )

    class Meta:
        model = TenantSubscription
        fields = [
            'id', 'tenant', 'tenant_name', 'plan', 'plan_name',
            'status', 'billing_cycle',
            'current_period_start', 'current_period_end',
            'trial_end', 'next_invoice_date',
            'current_price',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


# ─── Tenant Invoices ──────────────────────────────────────────────────────────

class TenantInvoiceSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source='tenant.name', read_only=True)

    class Meta:
        model = TenantInvoice
        fields = [
            'id', 'invoice_number', 'tenant', 'tenant_name',
            'amount', 'tax_amount', 'total', 'status',
            'period_start', 'period_end', 'due_date', 'paid_at',
            'notes', 'created_at',
        ]
        read_only_fields = ['invoice_number', 'created_at']


# ─── Tenant Usage ─────────────────────────────────────────────────────────────

class TenantUsageSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source='tenant.name', read_only=True)

    class Meta:
        model = TenantUsage
        fields = [
            'id', 'tenant', 'tenant_name', 'period',
            'order_count', 'customer_count', 'staff_count',
            'menu_item_count', 'subscription_count', 'revenue',
            'created_at',
        ]
        read_only_fields = ['created_at']


# ─── Platform Analytics ───────────────────────────────────────────────────────

class PlatformAnalyticsSerializer(serializers.Serializer):
    """Read-only aggregated platform metrics."""
    total_tenants = serializers.IntegerField()
    active_tenants = serializers.IntegerField()
    trial_tenants = serializers.IntegerField()
    total_revenue_monthly = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_revenue_yearly = serializers.DecimalField(max_digits=12, decimal_places=2)
    pending_invoices = serializers.IntegerField()
    overdue_invoices = serializers.IntegerField()
