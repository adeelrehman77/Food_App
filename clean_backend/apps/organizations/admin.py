from django.contrib import admin
from apps.organizations.models import ServicePlan

@admin.register(ServicePlan)
class ServicePlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'has_inventory_management', 'created_at')
    search_fields = ('name',)
