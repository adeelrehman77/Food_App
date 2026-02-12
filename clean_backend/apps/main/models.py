from decimal import Decimal
from django.db import models, transaction
from django.apps import apps
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.core.cache import cache

from apps.main.utils.validators import (
    validate_image_file_extension, validate_image_file_size_5mb,
    validate_video_file_extension, validate_video_file_size_10mb,
    validate_image_file_size_2mb
)

# Simple cache decorator if not imported
def cache_model_method(timeout=3600):
    def decorator(func):
        def wrapper(self, *args, **kwargs):
            cache_key = f"{self.__class__.__name__}:{self.pk}:{func.__name__}"
            result = cache.get(cache_key)
            if result is None:
                result = func(self, *args, **kwargs)
                cache.set(cache_key, result, timeout)
            return result
        return wrapper
    return decorator


class Category(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "Categories"


class TimeSlot(models.Model):
    name = models.CharField(max_length=50)
    time = models.CharField(max_length=100)
    start_time = models.TimeField()
    end_time = models.TimeField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.time})"


class CustomerProfile(models.Model):
    """
    Extends the default Django User model with customer-specific information.
    
    Note: `tenant_id` is stored as an IntegerField (not a ForeignKey) because
    Tenant lives in the shared/default database while CustomerProfile lives in
    the tenant-specific database. Cross-database FKs are not supported by
    PostgreSQL. The tenant is already implicit from the database being used;
    this field exists only for reference/auditing.
    """
    user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE, 
        related_name='customerprofile', 
        db_index=True
    )
    tenant_id = models.IntegerField(
        null=True, blank=True, db_index=True,
        help_text="References Tenant.id in the shared database (not a FK due to multi-DB)",
    )
    name = models.CharField(
        max_length=100, 
        blank=True, 
        help_text="Full name (optional)"
    )
    phone = models.CharField(
        max_length=20, 
        blank=True, 
        null=True, 
        db_index=True
    )
    emirates_id = models.CharField(max_length=20, blank=True)
    
    zone = models.CharField(
        max_length=100, 
        blank=True, 
        null=True, 
        help_text="Delivery zone"
    )
    route = models.ForeignKey(
        'driver.Route', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True
    )
    wallet_balance = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        default=Decimal('0.00')
    )
    preferred_communication = models.CharField(
        max_length=20,
        choices=[('whatsapp', 'WhatsApp'), ('sms', 'SMS'), ('email', 'Email'), ('none', 'None')],
        default='whatsapp',
        help_text="Preferred contact method"
    )
    plus_code = models.CharField(
        max_length=20, 
        blank=True, 
        null=True, 
        help_text="Google Plus Code"
    )
    notification_preferences = models.JSONField(
        default=dict, 
        blank=True,
        help_text="JSON: {'email': true, 'sms': true, 'push': true}"
    )
    loyalty_points = models.IntegerField(default=0)
    loyalty_tier = models.CharField(
        max_length=20,
        choices=[('BRONZE', 'Bronze'), ('SILVER', 'Silver'), ('GOLD', 'Gold')],
        default='BRONZE'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"[Tenant #{self.tenant_id or '?'}] {self.user.username} ({self.phone or 'No Phone'})"

    @staticmethod
    def get_default_notifications():
        return {"email": True, "sms": True, "push": True}

    class Meta:
        verbose_name = "Customer Profile"
        verbose_name_plural = "Customer Profiles"


class MenuItem(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    image = models.ImageField(upload_to='menu/', blank=True, null=True)
    calories = models.PositiveIntegerField(default=0, help_text="Calorie count per serving")
    allergens = models.JSONField(default=list, blank=True, help_text="List of allergens, e.g. ['Gluten', 'Dairy']")
    is_available = models.BooleanField(default=True)
    inventory_item = models.ForeignKey(
        'inventory.InventoryItem',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='menu_items',
        help_text="Link to an inventory item for stock tracking",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name


class Menu(models.Model):
    """
    Model representing a collection of menu items (e.g., Weekly Plan).
    """
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    menu_items = models.ManyToManyField(MenuItem, related_name='menus')
    price = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Address(models.Model):
    customer = models.ForeignKey(
        CustomerProfile, 
        on_delete=models.CASCADE, 
        related_name='addresses', 
        db_index=True
    )
    street = models.CharField(max_length=200, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    building_name = models.CharField(max_length=100, blank=True, null=True)
    floor_number = models.CharField(max_length=10, blank=True, null=True)
    flat_number = models.CharField(max_length=10, blank=True, null=True)
    is_default = models.BooleanField(default=False, db_index=True)
    status = models.CharField(
        max_length=20,
        choices=[('pending', 'Pending'), ('active', 'Active'), ('rejected', 'Rejected')],
        default='pending',
        db_index=True
    )
    requested_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='address_requests'
    )
    requested_at = models.DateTimeField(null=True, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    processed_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='processed_addresses'
    )
    admin_notes = models.TextField(blank=True, null=True)
    reason = models.TextField(
        blank=True, 
        help_text="Reason for change request (customer-provided)"
    )
    notify_customer = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        parts = [self.building_name or "", 
                 f"Floor {self.floor_number}" if self.floor_number else "", 
                 f"Flat {self.flat_number}" if self.flat_number else ""]
        building_part = " - ".join(filter(None, parts))
        return f"{self.street or ''}, {self.city or ''} {building_part}".strip(", ")

    def clean(self):
        if not any([self.street, self.building_name]):
            raise ValidationError("Either street or building name must be provided.")
        if self.floor_number and not self.floor_number.replace('-', '').isdigit():
            raise ValidationError("Floor number must be numeric.")
        if self.flat_number and not self.flat_number.replace('-', '').replace('/', '').isalnum():
            raise ValidationError("Invalid flat number format.")
        
        if self.status == 'pending' and not self.pk:
            current_active = Address.objects.filter(
                customer=self.customer, status='active', is_default=True
            ).first()
            if current_active and all([
                self.street == current_active.street,
                self.city == current_active.city,
                self.building_name == current_active.building_name,
                self.floor_number == current_active.floor_number,
                self.flat_number == current_active.flat_number
            ]):
                raise ValidationError("New address must differ from the current active default address.")

    def save(self, *args, **kwargs):
        self.full_clean()
        if self.pk is None:
            self.requested_at = timezone.now()
            self.requested_by = kwargs.pop('user', self.requested_by) or self.requested_by
        elif self.status == 'pending' and not self.requested_at:
            self.requested_at = timezone.now()
            self.requested_by = kwargs.pop('user', self.requested_by) or self.requested_by

        if self.status == 'active' and self.is_default:
            Address.objects.filter(customer=self.customer).exclude(pk=self.pk).update(is_default=False)
            
        super().save(*args, **kwargs)

    def approve(self, user):
        if self.status != 'pending': return False
        with transaction.atomic():
            self.status = 'active'
            self.processed_at = timezone.now()
            self.processed_by = user
            self.save(update_fields=['status', 'processed_at', 'processed_by', 'is_default']) 

            if self.notify_customer:
                Notification.objects.create(
                    customer=self.customer,
                    message=f"Your address change request has been approved: {self.__str__()}.",
                    priority='high'
                )
        return True

    def reject(self, user, reason=''):
        if self.status != 'pending': return False
        with transaction.atomic():
            self.status = 'rejected'
            self.processed_at = timezone.now()
            self.processed_by = user
            self.admin_notes = reason
            self.save(update_fields=['status', 'processed_at', 'processed_by', 'admin_notes'])
            if self.notify_customer:
                Notification.objects.create(
                    customer=self.customer,
                    message=f"Your address change request was rejected: {reason}",
                    priority='high'
                )
        return True

    class Meta:
        verbose_name_plural = "Addresses"
        ordering = ['-is_default', '-status', 'building_name']
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['customer', 'is_default']),
        ]


class Subscription(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, db_index=True)
    menus = models.ManyToManyField(Menu, verbose_name='Menu Plans', help_text="Select the menus included in this subscription.")
    lunch_address = models.ForeignKey(Address, on_delete=models.SET_NULL, null=True, blank=True, related_name='lunch_subscriptions', help_text="Optional: specific address for lunch deliveries.")
    dinner_address = models.ForeignKey(Address, on_delete=models.SET_NULL, null=True, blank=True, related_name='dinner_subscriptions', help_text="Optional: specific address for dinner deliveries.")
    status = models.CharField(
        max_length=20, 
        choices=[('pending', 'Pending'), ('active', 'Active'), ('paused', 'Paused'), ('expired', 'Expired'), ('cancelled', 'Cancelled')], 
        default='pending', 
        db_index=True
    )
    start_date = models.DateField(db_index=True)
    end_date = models.DateField(db_index=True)
    time_slot = models.ForeignKey(TimeSlot, on_delete=models.CASCADE, null=True, blank=True, help_text="The main time slot for deliveries (e.g., Lunch, Dinner).")
    
    DAYS_CHOICES = [
        ('Monday', 'Monday'), ('Tuesday', 'Tuesday'), ('Wednesday', 'Wednesday'),
        ('Thursday', 'Thursday'), ('Friday', 'Friday'), ('Saturday', 'Saturday'), ('Sunday', 'Sunday')
    ]
    selected_days = models.JSONField(default=list, help_text='Select the days for delivery')
    payment_mode = models.CharField(max_length=20, choices=[('wallet', 'Wallet'), ('card', 'Card'), ('cash', 'Cash')], default='wallet')
    want_notifications = models.BooleanField(default=True)
    dietary_preferences = models.CharField(max_length=100, blank=True, help_text="e.g., 'Gluten-free', 'Vegan'")
    special_instructions = models.TextField(blank=True)
    cost_per_meal = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    total_cost = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))

    MAX_SUBSCRIPTIONS_PER_USER = 3
    MINIMUM_SUBSCRIPTION_DAYS = 7

    def __str__(self):
        return f"Subscription for {self.customer.name} from {self.start_date} to {self.end_date}"

    @cache_model_method(timeout=3600)
    def get_selected_days(self):
        return self.selected_days or []

    def set_selected_days(self, days_list):
        self.selected_days = days_list
        cache_key = f"{self.__class__.__name__}:{self.pk}:get_selected_days"
        cache.delete(cache_key)

    @cache_model_method(timeout=3600)
    def get_next_delivery_date(self):
        if self.status not in ['active', 'paused']: return None
        current_date = max(self.start_date, timezone.now().date())
        selected_days_list = self.get_selected_days()
        while current_date <= self.end_date:
            if current_date.strftime('%A') in selected_days_list:
                return current_date
            current_date += timezone.timedelta(days=1)
        return None

    def calculate_total_cost(self):
        # Assuming menus are prefetched or efficiently accessed
        menu_prices = [menu.price for menu in self.menus.all()] if self.pk else []
        self.cost_per_meal = sum(menu_prices) or Decimal('0.00')
        total_days_selected = len(self.get_selected_days())
        
        if self.start_date and self.end_date and total_days_selected > 0:
            delivery_dates_count = 0
            current_date = self.start_date
            selected_days_names = self.get_selected_days()
            while current_date <= self.end_date:
                if current_date.strftime('%A') in selected_days_names:
                    delivery_dates_count += 1
                current_date += timezone.timedelta(days=1)
            self.total_cost = self.cost_per_meal * delivery_dates_count
        else:
            self.total_cost = self.cost_per_meal 
        
        if self.total_cost < 0: self.total_cost = Decimal('0.00')
        return self.total_cost

    def clean(self):
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValidationError({'end_date': 'End date must be after start date.'})
        if not self.pk and self.start_date and self.start_date < timezone.now().date():
            raise ValidationError({'start_date': 'Start date cannot be in the past for new subscriptions.'})
        
        selected_days_list = self.get_selected_days()
        if not selected_days_list:
            raise ValidationError({'selected_days': 'At least one day must be selected.'})
        
        valid_days = [day[0] for day in self.DAYS_CHOICES]
        if not all(day in valid_days for day in selected_days_list):
            raise ValidationError({'selected_days': f'Invalid day selection.'})

        if not self.pk and (self.end_date - self.start_date).days + 1 < self.MINIMUM_SUBSCRIPTION_DAYS:
            raise ValidationError(f'Minimum subscription duration is {self.MINIMUM_SUBSCRIPTION_DAYS} days.')
        
        if not self.pk and Subscription.objects.filter(customer=self.customer, status__in=['active', 'pending']).count() >= self.MAX_SUBSCRIPTIONS_PER_USER:
            raise ValidationError(f'Maximum {self.MAX_SUBSCRIPTIONS_PER_USER} active subscriptions allowed.')

    def save(self, *args, **kwargs):
        self.calculate_total_cost() 
        self.full_clean()
        is_new = not self.pk
        super().save(*args, **kwargs)
        if self.status == 'active' and is_new:
            self.update_delivery_schedule()

    def update_delivery_schedule(self):
        try:
            DeliveryStatus = apps.get_model('driver', 'DeliveryStatus') # Updated app name to driver
        except LookupError:
            print("Warning: 'driver' app or 'DeliveryStatus' model not found.")
            return

        if self.status != 'active': return
        current_date = max(self.start_date, timezone.now().date())
        existing_deliveries = set(DeliveryStatus.objects.filter(subscription=self, date__gte=current_date).values_list('date', flat=True))
        
        required_dates = set()
        temp_date = current_date
        selected_days_list = self.get_selected_days()
        while temp_date <= self.end_date:
            if temp_date.strftime('%A') in selected_days_list:
                required_dates.add(temp_date)
            temp_date += timezone.timedelta(days=1)
        
        dates_to_cancel = existing_deliveries - required_dates
        if dates_to_cancel:
            DeliveryStatus.objects.filter(subscription=self, date__in=dates_to_cancel, status='pending').update(status='cancelled')

        new_dates = required_dates - existing_deliveries
        if new_dates:
            DeliveryStatus.objects.bulk_create([
                DeliveryStatus(subscription=self, date=date, status='pending') for date in new_dates
            ])

    class Meta:
        verbose_name_plural = "Subscriptions"
        ordering = ['-start_date', '-end_date']
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['start_date', 'end_date']),
            models.Index(fields=['customer', 'start_date']),
        ]

class Order(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'), ('confirmed', 'Confirmed'), ('preparing', 'Preparing'),
        ('ready', 'Ready'), ('delivered', 'Delivered'), ('cancelled', 'Cancelled')
    ]
    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE)
    order_date = models.DateField()
    delivery_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    quantity = models.IntegerField(default=1)
    special_instructions = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order {self.id} - {self.subscription.customer.user.get_full_name()}"


class SubscriptionEditRequest(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE)
    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE)
    requested_changes = models.JSONField(help_text='JSON object detailing the requested changes')
    status = models.CharField(max_length=20, choices=[('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')], default='pending')
    requested_at = models.DateTimeField(auto_now_add=True)

    def can_edit(self):
        return (timezone.now() - self.requested_at).total_seconds() > 24 * 3600

    def __str__(self):
        return f"Edit Request for {self.subscription} by {self.customer} - {self.status}"


class Invoice(models.Model):
    PAYMENT_STATUS = [('pending', 'Pending'), ('paid', 'Paid'), ('failed', 'Failed'), ('refunded', 'Refunded')]
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE)
    invoice_number = models.CharField(max_length=50, unique=True)
    date = models.DateField(auto_now_add=True)
    due_date = models.DateField()
    total = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=PAYMENT_STATUS, default='pending')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.invoice_number} - {self.customer.user.username} - {self.status}"


class InvoiceItem(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.CASCADE, related_name='items')
    menu = models.ForeignKey(Menu, on_delete=models.CASCADE)
    quantity = models.DecimalField(max_digits=10, decimal_places=2, default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    
    def __str__(self):
        return f"{self.invoice.invoice_number} - {self.menu.name} x {self.quantity}"


class Notification(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    sent = models.BooleanField(default=False)
    sent_at = models.DateTimeField(null=True, blank=True)
    priority = models.CharField(
        max_length=20, 
        choices=[('low', 'Low'), ('medium', 'Medium'), ('high', 'High'), ('urgent', 'Urgent')], 
        default='medium'
    )

    def __str__(self):
        return f"Notification for {self.customer.name} - {self.created_at.strftime('%Y-%m-%d %H:%M')}"


class WalletTransaction(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal('0.01'))])
    transaction_type = models.CharField(max_length=10, choices=[('credit', 'Credit'), ('debit', 'Debit')])
    description = models.TextField()
    reference_id = models.CharField(max_length=100, unique=True, blank=True, null=True)
    subscription = models.ForeignKey(Subscription, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    invoice = models.ForeignKey(Invoice, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return f"{self.transaction_type.capitalize()} of {self.amount} for {self.customer.name}"

    def save(self, *args, **kwargs):
        if not self.reference_id:
            self.reference_id = str(uuid.uuid4())
        
        if not self.pk: 
            with transaction.atomic():
                if self.transaction_type == 'credit':
                    self.customer.wallet_balance += self.amount
                else: 
                    new_balance = self.customer.wallet_balance - self.amount
                    if new_balance < 0:
                        Notification.objects.create(
                            customer=self.customer,
                            message=f"Urgent: Your wallet balance is now negative (AED {new_balance:.2f}). Please add funds.",
                            priority='urgent'
                        )
                    self.customer.wallet_balance = new_balance
                self.customer.save(update_fields=['wallet_balance']) 
        
        super().save(*args, **kwargs)




class CustomerRegistrationRequest(models.Model):
    name = models.CharField(max_length=100)
    contact_number = models.CharField(max_length=20)
    address = models.TextField()
    meal_selection = models.CharField(max_length=10, choices=[('lunch', 'Lunch'), ('dinner', 'Dinner')])
    meal_type = models.CharField(max_length=10, choices=[('veg', 'Vegetarian'), ('nonveg', 'Non-Vegetarian')])
    quantity = models.PositiveIntegerField()
    status = models.CharField(max_length=10, choices=[('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    processed_by = models.ForeignKey('auth.User', null=True, blank=True, on_delete=models.SET_NULL, related_name='processed_registrations')
    admin_notes = models.TextField(blank=True, null=True)
    rejection_reason = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.name} ({self.contact_number}) - {self.status}"

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Customer Registration Request'
        verbose_name_plural = 'Customer Registration Requests'

class ManagerProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='manager_profile')
    is_manager = models.BooleanField(default=True)
    
    def __str__(self):
        return f"Manager: {self.user.username}"

class KitchenProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='kitchen_profile')
    is_kitchen_staff = models.BooleanField(default=True)

    def __str__(self):
        return f"Kitchen Staff: {self.user.username}"