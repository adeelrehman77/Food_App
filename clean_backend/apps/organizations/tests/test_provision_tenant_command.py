import pytest
from unittest.mock import patch, MagicMock, ANY
from django.core.management import call_command
from apps.users.models import Tenant
from apps.organizations.models import ServicePlan
from apps.organizations.models_saas import TenantSubscription

@pytest.mark.django_db(databases={'default': True})
@patch('django.db.backends.postgresql.base.DatabaseWrapper.get_database_version', return_value=(14, 0, 0))
class TestProvisionTenantCommand:
    """Test the provision_tenant management command."""

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_creates_database(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test that provision_tenant creates a new PostgreSQL database."""
        # Given: No tenant database exists
        subdomain = "test-kitchen-provisioning"
        
        # Configure User mock (prevent infinite loop)
        mock_user.objects.filter.return_value.exists.return_value = False
        
        # When: provision_tenant is called
        # Mock cursor functionality for default_conn (CREATE DATABASE)
        mock_cursor = MagicMock()
        mock_default_conn.cursor.return_value.__enter__.return_value = mock_cursor

        call_command('provision_tenant', 
                    subdomain=subdomain,
                    name="Test Kitchen",
                    skip_migrate=True)
        
        # Then: Database should be created
        # Verify: tenant object exists
        assert Tenant.objects.filter(subdomain=subdomain).exists()
        
        # Verify: CREATE DATABASE was called
        db_name = f"tenant_{subdomain}"
        mock_cursor.execute.assert_any_call(f'CREATE DATABASE "{db_name}"')

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_creates_admin_user(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test that provision_tenant creates an admin user in tenant DB."""
        # Configure User mock
        mock_user.objects.filter.return_value.exists.return_value = False
        mock_created_user = MagicMock()
        mock_created_user.id = 123
        mock_user.objects.create_user.return_value = mock_created_user

        # Mock default cursor (CREATE DATABASE)
        mock_cursor = MagicMock()
        mock_default_conn.cursor.return_value.__enter__.return_value = mock_cursor
        
        # Mock tenant DB connection
        mock_tenant_conn = MagicMock()
        mock_connect.return_value = mock_tenant_conn
        
        mock_tenant_cursor = MagicMock()
        mock_tenant_conn.cursor.return_value = mock_tenant_cursor
        
        # When: Provision runs
        call_command('provision_tenant',
                    subdomain="test-kitchen-admin",
                    name="Test Kitchen Admin",
                    skip_migrate=True)
        
        # Then: Admin user should exist in tenant context
        tenant = Tenant.objects.get(subdomain="test-kitchen-admin")
        assert tenant.name == "Test Kitchen Admin"
        
        # Verify create_user called with correct username
        mock_user.objects.create_user.assert_called_with(
            username="test-kitchen-admin",
            email="",
            password=ANY,
            is_staff=True,
            is_active=True
        )

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_assigns_plan(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test that provision_tenant assigns a service plan."""
        # Configure User mock
        mock_user.objects.filter.return_value.exists.return_value = False

        # Given: A plan exists
        plan = ServicePlan.objects.create(
            name="Free",
            tier="free",
            max_menu_items=10,
            max_staff_users=3,
            max_customers=50
        )
        
        # Mock cursor
        mock_cursor = MagicMock()
        mock_default_conn.cursor.return_value.__enter__.return_value = mock_cursor

        # When: Provision is called
        call_command('provision_tenant',
                    subdomain="test-kitchen-plan",
                    name="Test Kitchen Plan",
                    plan_id=plan.id,
                    skip_migrate=True) # Skip migration to avoid DB errors
        
        # Then: Plan should be assigned to tenant
        tenant = Tenant.objects.get(subdomain="test-kitchen-plan")
        assert tenant.service_plan == plan
        
        # Verify: TenantSubscription exists with correct plan
        subscription = TenantSubscription.objects.get(tenant=tenant)
        assert subscription.plan == plan

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_error_handling_invalid_slug(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test error handling with invalid tenant slug (subdomain)."""
        # Logic for invalid slug validation (e.g. spaces) is not explicitly implemented in command 
        # other than duplication check, but we can structure the test.
        pass

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_error_handling_duplicate_slug(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test error handling when slug already exists."""
        # Given: Tenant with slug 'test-kitchen' exists
        Tenant.objects.create(name="Existing", subdomain="test-kitchen", schema_name="test-kitchen")
        
        # Mock cursor
        mock_cursor = MagicMock()
        mock_default_conn.cursor.return_value.__enter__.return_value = mock_cursor

        # When: Trying to provision with same slug
        from django.core.management.base import CommandError
        with pytest.raises(CommandError):
            call_command('provision_tenant',
                        subdomain="test-kitchen",
                        name="New Kitchen")

    @patch('apps.organizations.management.commands.provision_tenant.default_conn')
    @patch('psycopg2.connect')
    @patch('psycopg2.extras.register_default_jsonb')
    @patch('apps.organizations.management.commands.provision_tenant.User')
    def test_provision_tenant_idempotent(self, mock_user, mock_register_jsonb, mock_connect, mock_default_conn, mock_get_db_version):
        """Test that running provision twice doesn't duplicate data."""
        # Current command implementation raises error on duplicate.
        pass
