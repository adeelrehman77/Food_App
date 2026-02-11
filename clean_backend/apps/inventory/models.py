from django.db import models


class UnitOfMeasure(models.Model):
    name = models.CharField(max_length=50)
    abbreviation = models.CharField(max_length=10)
    category = models.CharField(max_length=20)  # weight, volume, unit
    conversion_factor = models.DecimalField(max_digits=10, decimal_places=4, default=1.0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.abbreviation})"


class InventoryItem(models.Model):
    tenant = models.ForeignKey('users.Tenant', on_delete=models.CASCADE, related_name='inventory_items', null=True, blank=True)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    unit = models.ForeignKey(UnitOfMeasure, on_delete=models.CASCADE)
    current_stock = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    min_stock_level = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"[{self.tenant.name}] {self.name} - {self.current_stock} {self.unit.abbreviation}"
