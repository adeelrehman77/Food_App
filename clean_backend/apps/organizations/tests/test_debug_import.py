import pytest
from apps.users.models import Tenant

@pytest.mark.django_db
def test_import_tenant():
    print("DEBUG: Creating tenant")
    t = Tenant.objects.create(name="Test", subdomain="test", schema_name="test")
    print(f"DEBUG: Created {t}")
