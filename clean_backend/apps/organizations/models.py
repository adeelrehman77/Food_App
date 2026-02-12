from decimal import Decimal
from django.db import models


class ServicePlan(models.Model):
    """
    Defines what a tenant (kitchen business) gets at each pricing tier.
    The SaaS owner creates plans; tenants are assigned to one.
    """
    TIER_CHOICES = [
        ('free', 'Free / Trial'),
        ('basic', 'Basic'),
        ('pro', 'Professional'),
        ('enterprise', 'Enterprise'),
    ]

    name = models.CharField(max_length=100)
    tier = models.CharField(max_length=20, choices=TIER_CHOICES, default='basic')
    description = models.TextField(blank=True)

    # Pricing
    price_monthly = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal('0.00'),
        help_text="Monthly subscription price for the tenant",
    )
    price_yearly = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal('0.00'),
        help_text="Yearly subscription price (discounted)",
    )
    trial_days = models.PositiveIntegerField(
        default=14,
        help_text="Number of free trial days for new tenants",
    )

    # Usage limits (0 = unlimited)
    # Context: Each kitchen serves 300-500 customers per meal (breakfast/lunch/dinner),
    # so a single kitchen handles ~900-1,500 deliveries/day = 27,000-45,000/month.
    max_menu_items = models.PositiveIntegerField(
        default=100,
        help_text="Max menu items the kitchen can create (0 = unlimited)",
    )
    max_staff_users = models.PositiveIntegerField(
        default=15,
        help_text="Max kitchen/admin staff accounts (0 = unlimited)",
    )
    max_customers = models.PositiveIntegerField(
        default=1000,
        help_text="Max registered B2C customers / subscribers (0 = unlimited)",
    )
    max_orders_per_month = models.PositiveIntegerField(
        default=50000,
        help_text="Max meal deliveries per month (0 = unlimited)",
    )

    # Feature flags
    has_inventory_management = models.BooleanField(default=False)
    has_delivery_tracking = models.BooleanField(default=False)
    has_customer_app = models.BooleanField(default=False)
    has_analytics = models.BooleanField(default=False)
    has_whatsapp_notifications = models.BooleanField(default=False)
    has_multi_branch = models.BooleanField(default=False)
    features = models.JSONField(
        default=dict, blank=True,
        help_text="Additional feature flags as JSON, e.g. {'custom_branding': true}",
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['price_monthly']

    def __str__(self):
        return f"{self.name} ({self.get_tier_display()})"

    def has_feature(self, feature_name):
        """Check a named feature flag — looks in both boolean fields and JSON."""
        # Check dedicated boolean fields first
        field_name = f"has_{feature_name}"
        if hasattr(self, field_name):
            return getattr(self, field_name)
        # Fall back to JSON features dict
        return self.features.get(feature_name, False)

    def check_limit(self, limit_name, current_count):
        """
        Returns True if the current count is within the plan limit.
        A limit of 0 means unlimited.
        """
        field_name = f"max_{limit_name}"
        limit = getattr(self, field_name, 0)
        if limit == 0:
            return True  # unlimited
        return current_count < limit
