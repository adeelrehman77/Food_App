from django.contrib import admin
from apps.driver.models import (
    Zone, Route, DeliveryDriver, DeliveryStatus,
    DeliveryAssignment, DeliverySchedule, DeliveryNotification,
)


@admin.register(Zone)
class ZoneAdmin(admin.ModelAdmin):
    list_display = ('name', 'delivery_fee', 'estimated_delivery_time', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name',)


@admin.register(Route)
class RouteAdmin(admin.ModelAdmin):
    list_display = ('name', 'zone', 'is_active')
    list_filter = ('zone', 'is_active')
    search_fields = ('name',)


@admin.register(DeliveryDriver)
class DeliveryDriverAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone', 'vehicle_number', 'vehicle_type', 'is_active')
    list_filter = ('is_active', 'vehicle_type')
    search_fields = ('name', 'phone', 'vehicle_number')


@admin.register(DeliveryStatus)
class DeliveryStatusAdmin(admin.ModelAdmin):
    list_display = ('subscription', 'date', 'status', 'payment_processed')
    list_filter = ('status', 'date', 'payment_processed')
    search_fields = ('subscription__customer__user__username',)
    date_hierarchy = 'date'


@admin.register(DeliveryAssignment)
class DeliveryAssignmentAdmin(admin.ModelAdmin):
    list_display = ('delivery_status', 'driver', 'assigned_at')
    list_filter = ('driver',)


@admin.register(DeliverySchedule)
class DeliveryScheduleAdmin(admin.ModelAdmin):
    list_display = ('zone', 'day_of_week', 'start_time', 'end_time', 'max_deliveries', 'is_active')
    list_filter = ('zone', 'day_of_week', 'is_active')


@admin.register(DeliveryNotification)
class DeliveryNotificationAdmin(admin.ModelAdmin):
    list_display = ('delivery_status', 'notification_type', 'sent_via', 'is_sent', 'sent_at')
    list_filter = ('notification_type', 'sent_via', 'is_sent')
