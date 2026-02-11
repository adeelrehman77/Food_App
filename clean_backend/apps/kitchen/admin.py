from django.contrib import admin
from apps.kitchen.models import APIKey, KitchenOrder

@admin.register(APIKey)
class APIKeyAdmin(admin.ModelAdmin):
    list_display = ('user', 'name', 'is_active', 'expires_at')
    list_filter = ('is_active',)
    search_fields = ('name', 'user__username')

@admin.register(KitchenOrder)
class KitchenOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'order', 'assigned_to', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('order__id', 'assigned_to__username')
