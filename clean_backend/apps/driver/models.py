from django.db import models
from django.utils import timezone
from django.core.validators import MinValueValidator
from decimal import Decimal


class Zone(models.Model):
    """
    Model for delivery zones.
    """
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True, null=True)
    delivery_fee = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        default=Decimal('0.00'),
        validators=[MinValueValidator(Decimal('0.00'))]
    )
    estimated_delivery_time = models.IntegerField(
        default=30,
        help_text="Estimated delivery time in minutes"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} (AED {self.delivery_fee:.2f})"
    
    class Meta:
        ordering = ['name']


class Route(models.Model):
    """
    Model for delivery routes within zones.
    """
    name = models.CharField(max_length=100)
    zone = models.ForeignKey(
        Zone, 
        on_delete=models.CASCADE,
        related_name='routes'
    )
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} - {self.zone.name}"
    
    class Meta:
        ordering = ['zone__name', 'name']
        unique_together = ['name', 'zone']


class DeliveryStatus(models.Model):
    """
    Model for tracking delivery status of subscription deliveries.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('preparing', 'Preparing'),
        ('out_for_delivery', 'Out for Delivery'),
        ('delivered', 'Delivered'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]
    
    subscription = models.ForeignKey(
        'main.Subscription', 
        on_delete=models.CASCADE,
        related_name='delivery_statuses'
    )
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_time = models.TimeField(blank=True, null=True)
    actual_delivery_time = models.TimeField(blank=True, null=True)
    delivery_address = models.ForeignKey(
        'main.Address',
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    driver_notes = models.TextField(blank=True, null=True)
    customer_notes = models.TextField(blank=True, null=True)
    payment_processed = models.BooleanField(default=False)
    payment_amount = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        null=True, 
        blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.subscription} - {self.date} ({self.get_status_display()})"
    
    def process_payment(self):
        """
        Process payment for this delivery.
        """
        if not self.payment_processed and self.payment_amount:
            # Create wallet transaction for payment
            from apps.main.models import WalletTransaction
            
            WalletTransaction.objects.create(
                customer=self.subscription.customer,
                amount=self.payment_amount,
                transaction_type='debit',
                description=f'Payment for delivery on {self.date}',
                subscription=self.subscription
            )
            
            self.payment_processed = True
            self.save(update_fields=['payment_processed'])
            return True
        return False
    
    def mark_as_delivered(self, actual_time=None):
        """
        Mark delivery as completed.
        """
        self.status = 'delivered'
        if actual_time:
            self.actual_delivery_time = actual_time
        else:
            self.actual_delivery_time = timezone.now().time()
        self.save(update_fields=['status', 'actual_delivery_time'])
        
        # Process payment if not already processed
        if not self.payment_processed:
            self.process_payment()
    
    class Meta:
        verbose_name = "Delivery Status"
        verbose_name_plural = "Delivery Statuses"
        ordering = ['-date', '-created_at']
        unique_together = ['subscription', 'date']


class DeliveryDriver(models.Model):
    """
    Model for delivery drivers.
    """
    user = models.OneToOneField(
        'auth.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='driver_profile',
        help_text="Link to the system user account for authentication"
    )
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20, unique=True)
    email = models.EmailField(blank=True, null=True)
    vehicle_number = models.CharField(max_length=20, blank=True, null=True)
    vehicle_type = models.CharField(max_length=50, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    zones = models.ManyToManyField(
        Zone,
        blank=True,
        related_name='assigned_drivers',
        help_text="Zones this driver is assigned to cover",
    )
    routes = models.ManyToManyField(
        Route,
        blank=True,
        related_name='assigned_drivers',
        help_text="Specific routes this driver is assigned to",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} ({self.phone})"
    
    class Meta:
        ordering = ['name']


class DeliveryAssignment(models.Model):
    """
    Model for assigning deliveries to drivers.
    """
    delivery_status = models.OneToOneField(
        DeliveryStatus,
        on_delete=models.CASCADE,
        related_name='assignment'
    )
    driver = models.ForeignKey(
        DeliveryDriver,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    assigned_at = models.DateTimeField(auto_now_add=True)
    estimated_pickup_time = models.TimeField(blank=True, null=True)
    estimated_delivery_time = models.TimeField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    
    def __str__(self):
        return f"{self.delivery_status} - {self.driver.name if self.driver else 'Unassigned'}"
    
    class Meta:
        verbose_name = "Delivery Assignment"
        verbose_name_plural = "Delivery Assignments"


class DeliverySchedule(models.Model):
    """
    Model for managing delivery schedules and time slots.
    """
    DAYS_OF_WEEK = [
        (0, 'Monday'),
        (1, 'Tuesday'),
        (2, 'Wednesday'),
        (3, 'Thursday'),
        (4, 'Friday'),
        (5, 'Saturday'),
        (6, 'Sunday'),
    ]
    
    zone = models.ForeignKey(
        Zone,
        on_delete=models.CASCADE,
        related_name='delivery_schedules'
    )
    day_of_week = models.IntegerField(choices=DAYS_OF_WEEK)
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_deliveries = models.IntegerField(
        default=50,
        help_text="Maximum number of deliveries for this time slot"
    )
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.get_day_of_week_display()} - {self.start_time} to {self.end_time} ({self.zone.name})"
    
    class Meta:
        ordering = ['day_of_week', 'start_time']
        unique_together = ['zone', 'day_of_week', 'start_time']


class DeliveryNotification(models.Model):
    """
    Model for delivery-related notifications.
    """
    NOTIFICATION_TYPES = [
        ('delivery_confirmation', 'Delivery Confirmation'),
        ('delivery_reminder', 'Delivery Reminder'),
        ('delivery_update', 'Delivery Update'),
        ('delivery_completion', 'Delivery Completion'),
    ]
    
    delivery_status = models.ForeignKey(
        DeliveryStatus,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPES)
    message = models.TextField()
    sent_at = models.DateTimeField(auto_now_add=True)
    sent_via = models.CharField(
        max_length=20,
        choices=[
            ('sms', 'SMS'),
            ('email', 'Email'),
            ('whatsapp', 'WhatsApp'),
            ('push', 'Push Notification'),
        ]
    )
    is_sent = models.BooleanField(default=False)
    sent_to = models.CharField(max_length=100, blank=True, null=True)
    
    def __str__(self):
        return f"{self.delivery_status} - {self.get_notification_type_display()}"
    
    class Meta:
        ordering = ['-sent_at']
        verbose_name = "Delivery Notification"
        verbose_name_plural = "Delivery Notifications" 