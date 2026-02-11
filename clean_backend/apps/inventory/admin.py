from django.contrib import admin
from apps.inventory.models import UnitOfMeasure, InventoryItem

@admin.register(UnitOfMeasure)
class UnitOfMeasureAdmin(admin.ModelAdmin):
    list_display = ('name', 'abbreviation', 'category')
    search_fields = ('name', 'abbreviation')

@admin.register(InventoryItem)
class InventoryItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'tenant', 'unit', 'current_stock', 'min_stock_level')
    list_filter = ('tenant', 'unit')
    search_fields = ('name',)
