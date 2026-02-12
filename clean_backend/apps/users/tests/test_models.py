import pytest
from apps.users.models import Tenant, Domain, UserProfile
from django.contrib.auth import get_user_model

User = get_user_model()

@pytest.mark.django_db
class TestTenantModel:
    def test_create_tenant(self):
        tenant = Tenant.objects.create(
            name="Test Kitchen",
            subdomain="test-kitchen",
            schema_name="test_kitchen",
            db_name="test_db"
        )
        assert tenant.name == "Test Kitchen"
        assert str(tenant) == "Test Kitchen"
        assert tenant.is_active is True

    def test_tenant_subdomain_unique(self):
        Tenant.objects.create(name="T1", subdomain="unique", schema_name="t1")
        with pytest.raises(Exception): # IntegrityError
            Tenant.objects.create(name="T2", subdomain="unique", schema_name="t2")

@pytest.mark.django_db
class TestDomainModel:
    def test_create_domain(self):
        tenant = Tenant.objects.create(name="T1", subdomain="t1", schema_name="t1")
        domain = Domain.objects.create(domain="t1.example.com", tenant=tenant)
        assert domain.domain == "t1.example.com"
        assert domain.is_primary is True
        assert str(domain) == "t1.example.com"

@pytest.mark.django_db
class TestUserProfileModel:
    def test_create_user_profile(self):
        user = User.objects.create_user(username="testuser", password="password")
        tenant = Tenant.objects.create(name="T1", subdomain="t1", schema_name="t1")
        profile = UserProfile.objects.create(
            user=user,
            tenant=tenant,
            phone_number="1234567890",
            address="123 Main St"
        )
        assert profile.user == user
        assert profile.tenant == tenant
        assert profile.phone_number == "1234567890"
        assert str(profile) == user.get_full_name() or user.username
