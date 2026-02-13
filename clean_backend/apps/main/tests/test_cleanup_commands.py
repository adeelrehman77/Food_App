import pytest
from unittest.mock import patch, MagicMock, call
from django.core.management import call_command
from apps.users.models import Tenant

class TestCleanupCommands:
    """Test cleanup management commands."""

    def setup_method(self):
        """Setup test data."""
        self.tenant = MagicMock(spec=Tenant)
        self.tenant.id = 1
        self.tenant.subdomain = 'test'
        self.tenant.db_name = 'test_db'
        self.tenant.db_user = 'user'
        self.tenant.db_password = 'password'
        self.tenant.db_host = 'localhost'
        self.tenant.db_port = '5432'
        self.tenant.is_active = True

    @patch('apps.main.management.commands.clean_tenant_orders.Order')
    @patch('apps.main.management.commands.clean_tenant_orders.Tenant')
    def test_clean_tenant_orders_specific_tenant(self, mock_tenant_cls, mock_order):
        """Test clean_tenant_orders for a specific tenant."""
        # Given: Tenant found
        mock_tenant_cls.objects.using.return_value.filter.return_value = [self.tenant]
        
        # When: call command
        call_command('clean_tenant_orders', tenant='test', no_input=True)
        
        # Then:
        # 1. Tenant lookup
        mock_tenant_cls.objects.using.assert_called_with('default')
        
        # 2. Order count/delete on tenant DB
        db_alias = f"tenant_{self.tenant.id}"
        mock_order.objects.using.assert_called_with(db_alias)
        
        # Verify delete called
        using_return = mock_order.objects.using.return_value
        assert using_return.all.return_value.delete.called

    @patch('apps.main.management.commands.clean_tenant_orders.Order')
    @patch('apps.main.management.commands.clean_tenant_orders.Tenant')
    def test_clean_tenant_orders_all_tenants(self, mock_tenant_cls, mock_order):
        """Test clean_tenant_orders --all."""
        # Given: 2 tenants
        tenant2 = MagicMock(spec=Tenant)
        tenant2.id = 2
        tenant2.subdomain = 'test2'
        tenant2.db_name = 'test_db2'
        
        mock_tenant_cls.objects.using.return_value.filter.return_value = [self.tenant, tenant2]
        
        # When: call command --all
        call_command('clean_tenant_orders', all=True, no_input=True)
        
        # Then: Order delete called for both
        alias1 = f"tenant_{self.tenant.id}"
        alias2 = f"tenant_{tenant2.id}"
        
        # Verify calls to using()
        calls = [c.args[0] for c in mock_order.objects.using.call_args_list]
        assert alias1 in calls
        assert alias2 in calls

    @patch('apps.main.management.commands.clean_tenant_subscriptions.Subscription')
    @patch('apps.main.management.commands.clean_tenant_subscriptions.Tenant')
    def test_clean_tenant_subscriptions_specific_tenant(self, mock_tenant_cls, mock_subscription):
        """Test clean_tenant_subscriptions for a specific tenant."""
        # Given: Tenant
        mock_tenant_cls.objects.using.return_value.filter.return_value = [self.tenant]
        
        # When: call command
        call_command('clean_tenant_subscriptions', tenant='test', no_input=True)
        
        # Then: Subscription count/delete on tenant DB
        db_alias = f"tenant_{self.tenant.id}"
        mock_subscription.objects.using.assert_called_with(db_alias)
        
        # Verify delete called
        using_return = mock_subscription.objects.using.return_value
        assert using_return.all.return_value.delete.called
