from django.db import models

class ServicePlan(models.Model):
    name = models.CharField(max_length=100)
    has_inventory_management = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name
