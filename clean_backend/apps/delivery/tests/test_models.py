import pytest
from django.contrib.auth import get_user_model
from django.utils import timezone
from apps.main.models import Order, Subscription, CustomerProfile, MealSlot, MealPackage
from apps.delivery.models import Delivery

User = get_user_model()

@pytest.mark.django_db
class TestDeliveryModel:
    def setup_method(self):
        self.user = User.objects.create_user(username='delivery_user', password='password')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='1234567890')
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Standard", price=100.00)
        
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=timezone.now().date(),
            end_date=timezone.now().date() + timezone.timedelta(days=30),
            time_slot=self.slot,
            selected_days=['Monday']
        )
        self.order = Order.objects.create(
            subscription=self.sub, order_date=timezone.now().date(),
            delivery_date=timezone.now().date(), status='pending'
        )

    def test_create_delivery(self):
        delivery = Delivery.objects.create(order=self.order)
        assert str(delivery) == f"Delivery {self.order.id}"
        assert delivery.status == 'pending'
