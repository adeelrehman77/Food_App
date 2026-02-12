from django.contrib import admin
from apps.organizations.models import ServicePlan
from apps.organizations.models_saas import (
    TenantSubscription, TenantInvoice, TenantUsage,
)


@admin.register(ServicePlan)
class ServicePlanAdmin(admin.ModelAdmin):
    list_display = (
        'name', 'tier', 'price_monthly', 'max_menu_items',
        'max_staff_users', 'max_customers', 'max_orders_per_month',
        'is_active', 'created_at',
    )
    list_filter = ('tier', 'is_active')
    search_fields = ('name', 'description')
    fieldsets = (
        (None, {
            'fields': ('name', 'tier', 'description', 'is_active'),
        }),
        ('Pricing', {
            'fields': ('price_monthly', 'price_yearly', 'trial_days'),
        }),
        ('Usage Limits', {
            'fields': (
                'max_menu_items', 'max_staff_users',
                'max_customers', 'max_orders_per_month',
            ),
            'description': 'Set to 0 for unlimited.',
        }),
        ('Feature Flags', {
            'fields': (
                'has_inventory_management', 'has_delivery_tracking',
                'has_customer_app', 'has_analytics',
                'has_whatsapp_notifications', 'has_multi_branch',
                'features',
            ),
        }),
    )


@admin.register(TenantSubscription)
class TenantSubscriptionAdmin(admin.ModelAdmin):
    list_display = (
        'tenant', 'plan', 'status', 'billing_cycle',
        'current_period_start', 'current_period_end', 'trial_end',
    )
    list_filter = ('status', 'billing_cycle', 'plan')
    search_fields = ('tenant__name', 'tenant__subdomain')
    raw_id_fields = ('tenant', 'plan')


@admin.register(TenantInvoice)
class TenantInvoiceAdmin(admin.ModelAdmin):
    list_display = (
        'invoice_number', 'tenant', 'amount', 'total',
        'status', 'due_date', 'paid_at',
    )
    list_filter = ('status',)
    search_fields = ('invoice_number', 'tenant__name')
    raw_id_fields = ('tenant', 'subscription')
    readonly_fields = ('invoice_number',)


@admin.register(TenantUsage)
class TenantUsageAdmin(admin.ModelAdmin):
    list_display = (
        'tenant', 'period', 'order_count', 'customer_count',
        'staff_count', 'menu_item_count', 'revenue',
    )
    list_filter = ('period',)
    search_fields = ('tenant__name',)
    raw_id_fields = ('tenant',)
