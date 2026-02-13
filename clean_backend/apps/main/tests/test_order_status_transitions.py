import pytest
from datetime import date, timedelta
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.apps import apps
from apps.main.models import Order, Subscription, MealPackage
from apps.users.models import Tenant

@pytest.mark.django_db
class TestOrderStatusTransitions:
    """Test order status workflow and validations."""

    def setup_method(self):
        self.tenant = Tenant.objects.create(
            name="Test",
            subdomain="test",
            is_active=True
        )
        self.user = apps.get_model('auth', 'User').objects.create_user(username='testclient')
        self.profile = apps.get_model('main', 'CustomerProfile').objects.create(user=self.user, tenant_id=self.tenant.id)
        
        # Create required subscription dependencies
        self.package = MealPackage.objects.create(name="Standard", price=100)
        self.subscription = Subscription.objects.create(
            customer=self.profile,
            meal_package=self.package,
            start_date=date.today(),
            end_date=date.today() + timedelta(days=30),
            status='active',
            selected_days=['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        )
        
        self.order = Order.objects.create(
            subscription=self.subscription,
            order_date=date.today(),
            delivery_date=date.today(),
            status='pending',
            quantity=1
        )

    def test_cannot_transition_to_preparing_before_today(self):
        """Test that orders can't be preparing until delivery date is today."""
        # Given: Order with future delivery date
        future_order = Order.objects.create(
            subscription=self.subscription,
            order_date=date.today(),
            delivery_date=date.today() + timedelta(days=1),
            status='pending'
        )
        
        # When: Trying to transition to preparing
        future_order.status = 'preparing'
        
        with pytest.raises(ValidationError) as excinfo:
            future_order.full_clean()
        
        assert "Cannot prepare/ready order before delivery date" in str(excinfo.value)

    def test_can_transition_to_preparing_on_delivery_day(self):
        """Test that orders CAN be preparing on delivery day."""
        # Given: Order with today's delivery date (self.order)
        assert self.order.delivery_date == date.today()
        
        # When: Transitioning to preparing
        self.order.status = 'preparing'
        self.order.full_clean()  # Should not raise
        self.order.save()
        
        # Then: Transition succeeds
        assert self.order.status == 'preparing'

    def test_cannot_transition_to_ready_before_today(self):
        """Test that orders can't be ready until delivery day."""
        # Given: Order with future delivery date
        future_order = Order.objects.create(
            subscription=self.subscription,
            order_date=date.today(),
            delivery_date=date.today() + timedelta(days=1),
            status='pending'
        )
        
        # When: Trying to transition to ready
        future_order.status = 'ready'
        
        with pytest.raises(ValidationError) as excinfo:
            future_order.full_clean()
            
        assert "Cannot prepare/ready order before delivery date" in str(excinfo.value)

    def test_auto_creates_delivery_when_marked_ready(self):
        """Test that Delivery record is auto-created when order becomes ready."""
        # Given: Order in preparing state
        self.order.status = 'preparing'
        self.order.save()
        
        # When: Marking as ready
        self.order.status = 'ready'
        self.order.save()
        
        # Then: Delivery record created
        Delivery = apps.get_model('delivery', 'Delivery')
        assert Delivery.objects.filter(order=self.order).exists()
        delivery = Delivery.objects.get(order=self.order)
        assert delivery.status == 'pending'
