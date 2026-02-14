import pytest
from datetime import date, timedelta
from django.core.management import call_command
from django.utils import timezone
from django.db import connection
from django.conf import settings
from django.contrib.auth import get_user_model

from apps.users.models import Tenant
from apps.main.models import Order, Subscription, CustomerProfile, MealPackage, MealSlot
from apps.delivery.models import Delivery

User = get_user_model()
from unittest.mock import patch

@pytest.mark.django_db(transaction=True)
class TestAutoAdvanceTodayOrdersCommand:
    """Test auto_advance_today_orders command."""

    def setup_method(self):
        # Get the name of the test database currently in use
        test_db_name = connection.settings_dict['NAME']
        
        self.tenant = Tenant.objects.create(
            name="Test Tenant",
            subdomain="test",
            schema_name="test_schema",
            db_name=test_db_name,  # Point to the current test DB
            db_user=connection.settings_dict['USER'],
            db_password=connection.settings_dict['PASSWORD'],
            db_host=connection.settings_dict['HOST'],
            db_port=connection.settings_dict['PORT'],
            is_active=True
        )

        # Setup required related objects
        self.user = User.objects.create_user(username='test_user', password='password')
        self.profile = CustomerProfile.objects.create(
            user=self.user,
            tenant_id=self.tenant.id,
            name="Test Customer"
        )
        self.meal_package = MealPackage.objects.create(name="Standard", price=100)
        self.meal_slot = MealSlot.objects.create(name="Lunch", code="lunch")
        
        self.subscription = Subscription.objects.create(
            customer=self.profile,
            meal_package=self.meal_package,
            start_date=timezone.now().date(),
            end_date=timezone.now().date() + timedelta(days=30),
            time_slot=self.meal_slot,
            selected_days=['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
            status='active'
        )

        # Create orders for today (pending -> should advance)
        self.today_order = Order.objects.create(
            subscription=self.subscription,
            order_date=timezone.now().date(),
            delivery_date=timezone.now().date(),
            status='confirmed',
            quantity=1
        )

        # Create future order (should stay confirmed)
        self.future_order = Order.objects.create(
            subscription=self.subscription,
            order_date=timezone.now().date(),
            delivery_date=timezone.now().date() + timedelta(days=1),
            status='confirmed',
            quantity=1
        )

    def test_advances_confirmed_orders_to_ready(self):
        """Test that confirmed orders for today are advanced to ready."""
        # When: Command runs
        call_command('auto_advance_today_orders', '--all', '--no-input')
        
        # Then: Today's order is ready
        self.today_order.refresh_from_db()
        assert self.today_order.status == 'ready'
        
        # But: Future order stays confirmed
        self.future_order.refresh_from_db()
        assert self.future_order.status == 'confirmed'

    def test_creates_delivery_records(self):
        """Test that Delivery records are created."""
        # Ensure no delivery exists initially
        assert not Delivery.objects.filter(order=self.today_order).exists()
        
        # When: Command runs
        call_command('auto_advance_today_orders', '--all', '--no-input')
        
        # Then: Delivery records created for ready orders
        self.today_order.refresh_from_db()
        assert self.today_order.status == 'ready'
        assert Delivery.objects.filter(order=self.today_order).exists()

    def test_idempotent_execution(self):
        """Test that running twice doesn't break data."""
        # When: Run twice
        call_command('auto_advance_today_orders', '--all', '--no-input')
        call_command('auto_advance_today_orders', '--all', '--no-input')
        
        # Then: No duplicate deliveries
        assert Delivery.objects.filter(
            order=self.today_order
        ).count() == 1

    def test_selective_tenant_execution(self):
        """Test --tenant flag to process single tenant."""
        # Create another tenant
        test_db_name = connection.settings_dict['NAME']
        tenant2 = Tenant.objects.create(
            name="Test2", 
            subdomain="test2",
            schema_name="test2_schema",
            db_name=test_db_name,
            is_active=True
        )

        # Patch the internal method to verify calls without side effects
        with patch('apps.main.management.commands.auto_advance_today_orders.Command._advance_for_tenant') as mock_advance:
            # When: Command run for specific tenant (self.tenant / 'test')
            call_command('auto_advance_today_orders', tenant='test', no_input=True)
            
            # Then: Called once for tenant1
            assert mock_advance.call_count == 1
            # Verify the first arg to the first call was self.tenant
            # args[0] is tenant
            called_tenant = mock_advance.call_args[0][0]
            assert called_tenant.subdomain == 'test'

            # Reset
            mock_advance.reset_mock()

            # When: Run for --all
            call_command('auto_advance_today_orders', all=True, no_input=True)

            # Then: Called twice (once for each active tenant)
            assert mock_advance.call_count == 2
            called_subdomains = [call.args[0].subdomain for call in mock_advance.mock_calls]
            assert 'test' in called_subdomains
            assert 'test2' in called_subdomains
