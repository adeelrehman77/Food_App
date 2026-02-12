from django.contrib import admin
from apps.delivery.models import Delivery


@admin.register(Delivery)
class DeliveryAdmin(admin.ModelAdmin):
    list_display = ('id', 'order', 'driver', 'status', 'pickup_time', 'delivery_time', 'created_at')
    list_filter = ('status',)
    search_fields = ('order__id', 'driver__username')
    date_hierarchy = 'created_at'
    readonly_fields = ('created_at', 'updated_at')
