import pytest
from unittest.mock import patch, MagicMock, ANY
from django.core.management import call_command
from apps.users.models import Tenant

@pytest.mark.django_db(databases={'default': True})
class TestMigrateAllTenantsCommand:
    """Test the migrate_all_tenants management command."""

    def setup_method(self):
        """Create test tenants."""
        # Clean up existing tenants to ensure isolated test environment
        Tenant.objects.all().delete()
        
        self.tenant1 = Tenant.objects.create(
            name="Kitchen 1",
            subdomain="kitchen-1",
            schema_name="kitchen-1",
            db_name="tenant_kitchen_1",
            is_active=True
        )
        self.tenant2 = Tenant.objects.create(
            name="Kitchen 2",
            subdomain="kitchen-2",
            schema_name="kitchen-2",
            db_name="tenant_kitchen_2",
            is_active=True
        )

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_single(self, mock_call_command):
        """Test migrating all active tenants."""
        # When: migrate_all_tenants called
        call_command('migrate_all_tenants')
        
        # Then: call_command('migrate') should be called for each active tenant
        # We expect 2 calls to 'migrate' (once for each tenant)
        assert mock_call_command.call_count == 2
        
        # Verify calls
        calls = mock_call_command.call_args_list
        # Check args for first call (order might vary but sequential usually respects creation or ID)
        # We just verify that it was called with 'migrate' and correct database aliases
        
        db_aliases = [call.kwargs.get('database') for call in calls if call.args and call.args[0] == 'migrate']
        
        assert f"tenant_{self.tenant1.id}" in db_aliases
        assert f"tenant_{self.tenant2.id}" in db_aliases

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_specific_tenant(self, mock_call_command):
        """Test migrating a specific tenant."""
        # When: migrate_all_tenants called with --tenant=kitchen-1
        call_command('migrate_all_tenants',
                    tenant='kitchen-1')
        
        # Then: Only kitchen-1 is migrated
        assert mock_call_command.call_count == 1
        
        args, kwargs = mock_call_command.call_args
        assert args[0] == 'migrate'
        assert kwargs['database'] == f"tenant_{self.tenant1.id}"

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_with_parallel(self, mock_call_command):
        """Test parallel migration using --parallel flag."""
        # When: migrate_all_tenants --parallel called
        call_command('migrate_all_tenants',
                    parallel=True,
                    workers=2)
        
        # Then: 'migrate' called for both
        # Note: In parallel, checking exact call count is safe with MagicMock
        assert mock_call_command.call_count == 2
        
        db_aliases = [call.kwargs['database'] for call in mock_call_command.call_args_list]
        assert f"tenant_{self.tenant1.id}" in db_aliases
        assert f"tenant_{self.tenant2.id}" in db_aliases

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_skip_inactive(self, mock_call_command):
        """Test that inactive tenants are skipped."""
        # Given: One tenant is inactive
        self.tenant2.is_active = False
        self.tenant2.save()
        
        # When: migrate_all_tenants called
        call_command('migrate_all_tenants')
        
        # Then: Only active tenant (tenant1) is migrated
        assert mock_call_command.call_count == 1
        args, kwargs = mock_call_command.call_args
        assert kwargs['database'] == f"tenant_{self.tenant1.id}"

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_skip_no_db_name(self, mock_call_command):
        """Test that tenants without db_name are skipped."""
        # Given: Tenant with no db_name
        self.tenant2.db_name = ""
        self.tenant2.save()
        
        # When: migrate_all_tenants called
        call_command('migrate_all_tenants')
        
        # Then: Only valid tenant is migrated
        assert mock_call_command.call_count == 1
        args, kwargs = mock_call_command.call_args
        assert kwargs['database'] == f"tenant_{self.tenant1.id}"

    @patch('apps.organizations.management.commands.migrate_all_tenants.call_command')
    def test_migrate_all_tenants_error_handling(self, mock_call_command):
        """Test error handling when migration fails."""
        # Given: call_command raises an error for the first tenant
        def side_effect(command_name, *args, **kwargs):
            if kwargs.get('database') == f"tenant_{self.tenant1.id}":
                raise Exception("Migration failed")
            return None
            
        mock_call_command.side_effect = side_effect

        # When: migrate_all_tenants called
        # It should NOT raise exception, but catch it and print error
        call_command('migrate_all_tenants')
        
        # Then: Both were attempted (one failed, one succeeded)
        assert mock_call_command.call_count == 2
