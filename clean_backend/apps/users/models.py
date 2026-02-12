from django.db import models
from django.contrib.auth.models import User

class Tenant(models.Model):
    name = models.CharField(max_length=100)
    subdomain = models.CharField(max_length=100, unique=True, default='')
    schema_name = models.CharField(max_length=63, unique=True, default='') # Keep for compatibility with scripts
    service_plan = models.ForeignKey('organizations.ServicePlan', on_delete=models.SET_NULL, null=True, blank=True)
    
    # Database connection settings
    db_name = models.CharField(max_length=100, default='')
    db_user = models.CharField(max_length=100, default='')
    db_password = models.CharField(max_length=100, default='')
    db_host = models.CharField(max_length=100, default='localhost')
    db_port = models.CharField(max_length=10, default='5432')
    
    is_active = models.BooleanField(default=True)
    created_on = models.DateField(auto_now_add=True)

    def __str__(self):
        return self.name


class Domain(models.Model):
    domain = models.CharField(max_length=253, unique=True)
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='domains')
    is_primary = models.BooleanField(default=True)

    def __str__(self):
        return self.domain


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    tenant = models.ForeignKey(
        Tenant,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='staff_profiles',
        help_text="The tenant this user belongs to. NULL for platform-level superusers.",
    )
    phone_number = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.user.get_full_name()
