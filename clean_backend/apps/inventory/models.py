from django.db import models


class UnitOfMeasure(models.Model):
    CATEGORY_CHOICES = [
        ('weight', 'Weight'),
        ('volume', 'Volume'),
        ('unit', 'Unit/Piece'),
        ('length', 'Length'),
    ]

    name = models.CharField(max_length=50)
    abbreviation = models.CharField(max_length=10)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    conversion_factor = models.DecimalField(max_digits=10, decimal_places=4, default=1.0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['category', 'name']

    def __str__(self):
        return f"{self.name} ({self.abbreviation})"


class InventoryItem(models.Model):
    """
    Inventory item within a tenant's database.

    Note: ``tenant_id`` is an IntegerField (not FK) because this model lives
    in the tenant-specific database while Tenant lives in the shared database.
    The tenant is already implicit from the database routing.
    """
    tenant_id = models.IntegerField(
        null=True, blank=True, db_index=True,
        help_text="References Tenant.id in the shared database (not a FK due to multi-DB)",
    )
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    unit = models.ForeignKey(UnitOfMeasure, on_delete=models.CASCADE)
    current_stock = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    min_stock_level = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    cost_per_unit = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    supplier = models.CharField(max_length=200, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} — {self.current_stock} {self.unit.abbreviation}"

    @property
    def is_low_stock(self):
        return self.current_stock <= self.min_stock_level
