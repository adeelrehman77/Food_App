import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.delivery.models import Delivery
from apps.main.models import Order, Subscription, CustomerProfile, MealSlot, MealPackage
from django.utils import timezone

User = get_user_model()

@pytest.mark.django_db
class TestDeliveryDebug:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_superuser(username='admin', password='password', email='admin@test.com')
        self.client.force_authenticate(user=self.user)

    def test_simple_list(self):
        # Create minimal data
        slot = MealSlot.objects.create(name="Lunch", code="lunch")
        pkg = MealPackage.objects.create(name="Std", price=100)
        cust_user = User.objects.create_user(username='cust', password='pw')
        profile = CustomerProfile.objects.create(user=cust_user)
        sub = Subscription.objects.create(
             customer=profile, meal_package=pkg,
             start_date=timezone.now().date(),
             end_date=timezone.now().date() + timezone.timedelta(days=7),
             time_slot=slot, selected_days=['Monday']
        )
        order = Order.objects.create(subscription=sub, order_date=timezone.now().date(), delivery_date=timezone.now().date())
        Delivery.objects.create(order=order, status='pending')

        res = self.client.get('/api/v1/delivery/deliveries/')
        assert res.status_code == 200
