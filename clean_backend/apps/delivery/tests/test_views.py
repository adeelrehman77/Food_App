import pytest
from django.utils import timezone
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.delivery.models import Delivery
from apps.main.models import Order, Subscription, CustomerProfile, MealSlot, MealPackage
from core.permissions.plan_limits import PlanFeatureInventory # Just for setup if needed

User = get_user_model()

@pytest.mark.django_db
class TestDeliveryViewSet:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_superuser(username='admin', password='password', email='admin@test.com')
        self.client.force_authenticate(user=self.user)
        
        # Setup data
        self.customer_user = User.objects.create_user(username='cust', password='pw')
        self.profile = CustomerProfile.objects.create(user=self.customer_user)
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Std", price=100)
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=timezone.now().date(),
            end_date=timezone.now().date() + timezone.timedelta(days=30),
            time_slot=self.slot,
            selected_days=['Monday']
        )
        self.order = Order.objects.create(
            subscription=self.sub,
            order_date=timezone.now().date(),
            delivery_date=timezone.now().date(),
            status='ready'
        )
        self.delivery = Delivery.objects.create(order=self.order, status='pending')
        self.driver_user = User.objects.create_user(username='driver', password='pw', email='driver@test.com')

    def test_list_deliveries(self):
        response = self.client.get('/api/v1/delivery/deliveries/')
        assert response.status_code == 200
        assert len(response.data['results']) >= 1

    def test_assign_driver(self):
        url = f'/api/v1/delivery/deliveries/{self.delivery.id}/assign_driver/'
        
        # Missing ID
        res = self.client.post(url, {}, format='json')
        assert res.status_code == 400
        
        # Invalid ID
        res = self.client.post(url, {'driver_id': 9999}, format='json')
        assert res.status_code == 404
        
        # Valid
        res = self.client.post(url, {'driver_id': self.driver_user.id}, format='json')
        assert res.status_code == 200
        self.delivery.refresh_from_db()
        assert self.delivery.driver == self.driver_user

    def test_update_status(self):
        url = f'/api/v1/delivery/deliveries/{self.delivery.id}/update_status/'
        
        # Invalid
        res = self.client.post(url, {'status': 'bad_stat'}, format='json')
        assert res.status_code == 400
        
        # In transit (updates pickup time)
        res = self.client.post(url, {'status': 'in_transit'}, format='json')
        assert res.status_code == 200
        self.delivery.refresh_from_db()
        assert self.delivery.status == 'in_transit'
        assert self.delivery.pickup_time is not None
        
        # Delivered (updates delivery time)
        res = self.client.post(url, {'status': 'delivered'}, format='json')
        assert res.status_code == 200
        self.delivery.refresh_from_db()
        assert self.delivery.status == 'delivered'
        assert self.delivery.delivery_time is not None

    def test_stats(self):
        res = self.client.get('/api/v1/delivery/deliveries/stats/')
        assert res.status_code == 200
        assert 'total' in res.data
        assert 'today' in res.data
