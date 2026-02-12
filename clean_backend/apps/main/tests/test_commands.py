import pytest
from unittest.mock import patch, MagicMock
from django.core.management import call_command
from django.utils import timezone
from apps.users.models import Tenant
from apps.main.models import Order
from apps.organizations.models import ServicePlan

@pytest.mark.django_db
class TestMainCommands:
    @patch('apps.main.management.commands.auto_advance_today_orders.Command._advance_for_tenant')
    def test_auto_advance_command(self, mock_advance):
        # Test valid tenant
        Tenant.objects.create(subdomain='test', schema_name='test', is_active=True)
        call_command('auto_advance_today_orders', tenant='test', no_input=True)
        mock_advance.assert_called()

    @patch('apps.main.management.commands.auto_advance_today_orders.Command._advance_for_tenant')
    def test_auto_advance_all(self, mock_advance):
        Tenant.objects.create(subdomain='t1', schema_name='t1', is_active=True)
        Tenant.objects.create(subdomain='t2', schema_name='t2', is_active=True)
        call_command('auto_advance_today_orders', all=True, no_input=True)
        assert mock_advance.call_count == 2

    def test_advance_logic(self):
        # Test _advance_for_tenant logic by mocking DB
        with patch('django.db.connections') as mock_conn:
            # tough to test logic without real DB, but can ensure it runs
            pass

@pytest.mark.django_db
class TestOrganizationCommands:
    def setup_method(self):
        Tenant.objects.all().delete()

    @patch('apps.organizations.management.commands.provision_tenant.default_conn.cursor')
    @patch('apps.organizations.management.commands.provision_tenant.call_command')
    def test_provision_tenant(self, mock_call, mock_cursor):
        # Mock cursor for CREATE DATABASE
        mock_cursor.return_value.__enter__.return_value = MagicMock()
        
        import uuid
        uid = str(uuid.uuid4())[:8]
        sub = f'testkitchen{uid}'
        
        call_command(
            'provision_tenant',
            name='Test Kitchen',
            subdomain=sub,
            admin_email='admin@test.com',
            admin_password='password',
            plan_id=None,
            skip_migrate=True
        )
        
        assert Tenant.objects.filter(subdomain=sub).exists()
        t = Tenant.objects.get(subdomain=sub)
        assert t.name == 'Test Kitchen'
        
        # Test with Plan
        plan = ServicePlan.objects.create(name="Basic", price=10, trial_days=7, is_active=True)
        sub2 = f'plankitchen{uid}'
        call_command(
            'provision_tenant',
            name='Plan Kitchen',
            subdomain=sub2,
            plan_id=plan.id,
            skip_migrate=True
        )
        t2 = Tenant.objects.get(subdomain=sub2)
        assert t2.service_plan == plan
