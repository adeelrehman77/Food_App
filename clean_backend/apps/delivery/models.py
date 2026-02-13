from django.db import models
from django.contrib.auth.models import User
from apps.main.models import Order


class Delivery(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE)
    driver = models.ForeignKey(
        'driver.DeliveryDriver',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='deliveries',
        help_text="Assigned delivery driver"
    )
    # Keep legacy User field for backward compatibility (deprecated)
    driver_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='deliveries',
        help_text="Legacy: Use driver field instead"
    )
    pickup_time = models.DateTimeField(null=True, blank=True)
    delivery_time = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, default='pending')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Delivery {self.order.id}"

    @property
    def driver_name(self):
        """Get driver name from DeliveryDriver or User."""
        if self.driver:
            return self.driver.name
        if self.driver_user:
            return self.driver_user.get_full_name() or self.driver_user.username
        return None
