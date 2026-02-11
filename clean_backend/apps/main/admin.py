from django.contrib import admin
from apps.main.models import (
    Category, TimeSlot, CustomerProfile, MenuItem, Subscription, Order, Address, 
    WalletTransaction, Notification, Menu, Invoice, CustomerRegistrationRequest
)

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')
    search_fields = ('name',)

@admin.register(TimeSlot)
class TimeSlotAdmin(admin.ModelAdmin):
    list_display = ('name', 'time', 'start_time', 'end_time', 'is_active')
    list_filter = ('is_active',)

@admin.register(CustomerProfile)
class CustomerProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'tenant', 'phone', 'created_at')
    search_fields = ('user__username', 'user__first_name', 'user__last_name', 'phone')
    list_filter = ('tenant',)

@admin.register(Address)
class AddressAdmin(admin.ModelAdmin):
    list_display = ('customer', 'building_name', 'city', 'status', 'is_default')
    list_filter = ('status', 'is_default')
    search_fields = ('customer__user__username', 'street', 'city')

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('customer', 'priority', 'read', 'created_at')
    list_filter = ('priority', 'read')

@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ('customer', 'amount', 'transaction_type', 'created_at')
    list_filter = ('transaction_type',)

@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'price', 'is_available')
    list_filter = ('category', 'is_available')
    search_fields = ('name', 'description')

@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('customer', 'status', 'start_date', 'end_date', 'total_cost')
    list_filter = ('status', 'start_date', 'payment_mode')
    search_fields = ('customer__user__username', 'customer__phone')

@admin.register(Menu)
class MenuAdmin(admin.ModelAdmin):
    list_display = ('name', 'price', 'is_active', 'created_at')
    filter_horizontal = ('menu_items',)

@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ('invoice_number', 'customer', 'total', 'status', 'due_date')
    list_filter = ('status', 'date')

@admin.register(CustomerRegistrationRequest)
class CustomerRegistrationRequestAdmin(admin.ModelAdmin):
    list_display = ('name', 'contact_number', 'status', 'created_at')
    list_filter = ('status',)

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'subscription', 'order_date', 'status')
    list_filter = ('status', 'order_date')
    search_fields = ('id', 'subscription__customer__user__username')
