import pytest
from django.utils import timezone
from apps.driver.models import Zone, Route, DeliveryStatus, DeliveryDriver, DeliveryAssignment
from apps.main.models import Subscription, CustomerProfile, MealSlot, MealPackage
from django.contrib.auth import get_user_model

User = get_user_model()

@pytest.mark.django_db
class TestDriverModels:
    def setup_method(self):
        self.zone = Zone.objects.create(name="Dubai Marina", delivery_fee=10.00)
        self.route = Route.objects.create(name="Route 1", zone=self.zone)
        self.driver = DeliveryDriver.objects.create(name="John Doe", phone="123456789")
        
        self.user = User.objects.create_user(username='cust', password='pw')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='123')
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Std", price=100)
        
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=timezone.now().date(),
            end_date=timezone.now().date() + timezone.timedelta(days=30),
            time_slot=self.slot,
            selected_days=['Monday']
        )
        self.delivery_status = DeliveryStatus.objects.create(
            subscription=self.sub,
            date=timezone.now().date(),
            status='pending'
        )

    def test_zone_str(self):
        assert str(self.zone) == "Dubai Marina (AED 10.00)"

    def test_route_str(self):
        assert str(self.route) == "Route 1 - Dubai Marina"

    def test_delivery_process_payment(self):
        from decimal import Decimal
        self.delivery_status.payment_amount = Decimal('50.00')
        processed = self.delivery_status.process_payment()
        assert processed is True
        self.delivery_status.refresh_from_db()
        assert self.delivery_status.payment_processed is True

    def test_mark_as_delivered(self):
        self.delivery_status.mark_as_delivered()
        assert self.delivery_status.status == 'delivered'
        assert self.delivery_status.actual_delivery_time is not None

    def test_assignment(self):
        assign = DeliveryAssignment.objects.create(
            delivery_status=self.delivery_status, driver=self.driver
        )
        assert str(assign) == f"{self.delivery_status} - John Doe"
