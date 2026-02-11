from django.db import models

class SubscriptionPlan(models.Model):
    name = models.CharField(max_length=100)
    max_orders_per_month = models.IntegerField(default=100)
    has_inventory_management = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name
