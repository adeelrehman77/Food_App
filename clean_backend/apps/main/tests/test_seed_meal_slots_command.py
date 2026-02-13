import pytest
from unittest.mock import patch, MagicMock, ANY
from django.core.management import call_command
from django.conf import settings
from apps.users.models import Tenant

class TestSeedMealSlotsCommand:
    """Test the seed_meal_slots management command."""

    def setup_method(self):
        """Setup test data."""
        self.tenant = MagicMock(spec=Tenant)
        self.tenant.id = 1
        self.tenant.subdomain = 'test-kitchen'
        self.tenant.db_name = 'test_db'
        self.tenant.db_user = 'user'
        self.tenant.db_password = 'password'
        self.tenant.db_host = 'localhost'
        self.tenant.db_port = '5432'
        self.tenant.is_active = True

    @patch('apps.main.management.commands.seed_meal_slots.MealSlot')
    def test_seed_meal_slots_default_only(self, mock_meal_slot):
        """Test seeding default database only (no arguments)."""
        # Configure get_or_create to return (obj, created)
        mock_obj = MagicMock()
        mock_meal_slot.objects.using.return_value.get_or_create.return_value = (mock_obj, True)
        
        # When: call command without arguments
        call_command('seed_meal_slots')
        
        # Then: verify MealSlot.objects.using('default').get_or_create was called
        # The command calls self._seed('default') -> MealSlot.objects.using('default')
        
        # Check that using('default') was accessed
        mock_meal_slot.objects.using.assert_called_with('default')
        
        # Verify get_or_create called for Lunch and Dinner
        using_return = mock_meal_slot.objects.using.return_value
        assert using_return.get_or_create.call_count == 2
        
        # Verify call arguments
        calls = using_return.get_or_create.call_args_list
        codes = [call.kwargs['code'] for call in calls]
        assert 'lunch' in codes
        assert 'dinner' in codes

    @patch('apps.users.models.Tenant')
    @patch('apps.main.management.commands.seed_meal_slots.MealSlot')
    def test_seed_meal_slots_all_tenants(self, mock_meal_slot, mock_tenant_cls):
        """Test seeding all tenants with --all-tenants flag."""
        # Configure get_or_create
        mock_obj = MagicMock()
        mock_meal_slot.objects.using.return_value.get_or_create.return_value = (mock_obj, True)

        # Given: A mock tenant
        mock_tenant_cls.objects.filter.return_value = [self.tenant]
        
        # When: call command with --all-tenants
        call_command('seed_meal_slots', all_tenants=True)
        
        # Then: 
        # 1. seeded 'default'
        mock_meal_slot.objects.using.assert_any_call('default')
        
        # 2. seeded 'tenant_1'
        db_alias = f"tenant_{self.tenant.id}"
        mock_meal_slot.objects.using.assert_any_call(db_alias)
        
        # Verify get_or_create called
        # default calls
        default_calls = [c for c in mock_meal_slot.objects.using.mock_calls if c.args == ('default',)]
        tenant_calls = [c for c in mock_meal_slot.objects.using.mock_calls if c.args == (db_alias,)]
        assert len(default_calls) >= 1
        assert len(tenant_calls) >= 1

    @patch('apps.main.management.commands.seed_meal_slots.MealSlot')
    def test_seed_meal_slots_idempotent(self, mock_meal_slot):
        """Test that running seed twice is safe (idempotency handled by get_or_create)."""
        # Configure get_or_create
        mock_obj = MagicMock()
        mock_meal_slot.objects.using.return_value.get_or_create.return_value = (mock_obj, False) # Exists

        # When: call command
        call_command('seed_meal_slots')
        
        # Then: It relies on get_or_create, so we verify that method is used
        using_return = mock_meal_slot.objects.using.return_value
        # If get_or_create is used, it's idempotent by definition
        assert using_return.get_or_create.called
        assert not using_return.create.called

    @patch('apps.users.models.Tenant')
    @patch('apps.main.management.commands.seed_meal_slots.MealSlot')
    def test_seed_meal_slots_skip_no_db(self, mock_meal_slot, mock_tenant_cls):
        """Test skipping tenant if no db_name."""
        # Configure get_or_create
        mock_obj = MagicMock()
        mock_meal_slot.objects.using.return_value.get_or_create.return_value = (mock_obj, True)

        # Given: Tenant with no db_name
        self.tenant.db_name = ''
        mock_tenant_cls.objects.filter.return_value = [self.tenant]
        
        # When: call command
        call_command('seed_meal_slots', all_tenants=True)
        
        # Then: Should NOT seed this tenant
        # Should only seed default
        db_alias = f"tenant_{self.tenant.id}"
        
        # Verify using(db_alias) was NOT called
        aliases_called = [c.args[0] for c in mock_meal_slot.objects.using.call_args_list]
        assert 'default' in aliases_called
        assert db_alias not in aliases_called
