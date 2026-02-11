from django.contrib import admin
from apps.driver.models import DeliveryDriver

@admin.register(DeliveryDriver)
class DeliveryDriverAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone', 'vehicle_number', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'phone', 'vehicle_number')
