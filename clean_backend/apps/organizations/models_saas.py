"""
SaaS Owner (Layer 1) models.

These live in the shared/default database and track:
- Tenant subscriptions to service plans
- Billing invoices for tenants
- Usage metrics per tenant
"""
import uuid
from decimal import Decimal
from django.db import models
from django.utils import timezone


class TenantSubscription(models.Model):
    """
    Tracks a tenant's subscription to a ServicePlan.
    Managed by the SaaS owner / platform admin.
    """
    STATUS_CHOICES = [
        ('trial', 'Trial'),
        ('active', 'Active'),
        ('past_due', 'Past Due'),
        ('cancelled', 'Cancelled'),
        ('suspended', 'Suspended'),
    ]
    BILLING_CYCLE_CHOICES = [
        ('monthly', 'Monthly'),
        ('yearly', 'Yearly'),
    ]

    tenant = models.OneToOneField(
        'users.Tenant',
        on_delete=models.CASCADE,
        related_name='subscription',
    )
    plan = models.ForeignKey(
        'organizations.ServicePlan',
        on_delete=models.PROTECT,
        related_name='tenant_subscriptions',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='trial')
    billing_cycle = models.CharField(
        max_length=10, choices=BILLING_CYCLE_CHOICES, default='monthly',
    )

    # Period tracking
    current_period_start = models.DateField()
    current_period_end = models.DateField()
    trial_end = models.DateField(null=True, blank=True)

    # Billing
    next_invoice_date = models.DateField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.tenant.name} — {self.plan.name} ({self.get_status_display()})"

    @property
    def is_trial(self):
        return self.status == 'trial' and self.trial_end and self.trial_end >= timezone.now().date()

    @property
    def is_active_or_trial(self):
        return self.status in ('active', 'trial')

    @property
    def current_price(self):
        if self.billing_cycle == 'yearly':
            return self.plan.price_yearly
        return self.plan.price_monthly


class TenantInvoice(models.Model):
    """
    Invoices issued to tenants for their SaaS subscription.
    """
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('overdue', 'Overdue'),
        ('cancelled', 'Cancelled'),
    ]

    invoice_number = models.CharField(
        max_length=50, unique=True, editable=False,
    )
    tenant = models.ForeignKey(
        'users.Tenant',
        on_delete=models.CASCADE,
        related_name='saas_invoices',
    )
    subscription = models.ForeignKey(
        TenantSubscription,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='invoices',
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    tax_amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    total = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    period_start = models.DateField()
    period_end = models.DateField()
    due_date = models.DateField()
    paid_at = models.DateTimeField(null=True, blank=True)

    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.invoice_number} — {self.tenant.name} ({self.get_status_display()})"

    def save(self, *args, **kwargs):
        if not self.invoice_number:
            # Generate invoice number: INV-YYYYMM-XXXX
            now = timezone.now()
            prefix = f"INV-{now.strftime('%Y%m')}"
            last = TenantInvoice.objects.filter(
                invoice_number__startswith=prefix,
            ).count()
            self.invoice_number = f"{prefix}-{last + 1:04d}"
        if not self.total:
            self.total = self.amount + self.tax_amount
        super().save(*args, **kwargs)


class TenantUsage(models.Model):
    """
    Monthly usage snapshot for a tenant.
    Collected by a scheduled task (Celery/APScheduler).
    """
    tenant = models.ForeignKey(
        'users.Tenant',
        on_delete=models.CASCADE,
        related_name='usage_records',
    )
    period = models.DateField(help_text="First day of the month")

    # Usage metrics
    order_count = models.PositiveIntegerField(default=0)
    customer_count = models.PositiveIntegerField(default=0)
    staff_count = models.PositiveIntegerField(default=0)
    menu_item_count = models.PositiveIntegerField(default=0)
    subscription_count = models.PositiveIntegerField(default=0)
    revenue = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-period']
        unique_together = ['tenant', 'period']

    def __str__(self):
        return f"{self.tenant.name} — {self.period.strftime('%B %Y')}"
