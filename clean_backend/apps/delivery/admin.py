from django.contrib import admin
from apps.delivery.models import Delivery

@admin.register(Delivery)
class DeliveryAdmin(admin.ModelAdmin):
    list_display = ('id', 'order', 'driver', 'status')
    list_filter = ('status',)
    search_fields = ('order__id', 'driver__username')
