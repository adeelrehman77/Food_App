from django.contrib import admin
from apps.inventory.models import UnitOfMeasure, InventoryItem


@admin.register(UnitOfMeasure)
class UnitOfMeasureAdmin(admin.ModelAdmin):
    list_display = ('name', 'abbreviation', 'category', 'conversion_factor')
    list_filter = ('category',)
    search_fields = ('name', 'abbreviation')


@admin.register(InventoryItem)
class InventoryItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'unit', 'current_stock', 'min_stock_level', 'is_low_stock', 'is_active')
    list_filter = ('is_active', 'unit')
    search_fields = ('name', 'supplier')
