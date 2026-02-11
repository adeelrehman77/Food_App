from django.contrib import admin
from apps.organizations.models import SubscriptionPlan

@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'max_orders_per_month', 'has_inventory_management', 'created_at')
    search_fields = ('name',)
