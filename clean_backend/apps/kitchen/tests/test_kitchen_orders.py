import pytest
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.main.models import Order, Subscription, CustomerProfile, MealPackage, MealSlot
from apps.kitchen.models import KitchenOrder

User = get_user_model()

@pytest.mark.django_db
class TestKitchenOrderFlow:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        # Create user and staff
        self.staff_user = User.objects.create_user(username='chef', password='password')
        self.client.force_authenticate(user=self.staff_user)
        
        # Setup dependencies for Order
        self.customer_user = User.objects.create_user(username='customer', password='password')
        self.profile = CustomerProfile.objects.create(user=self.customer_user, phone='1234567890')
        self.package = MealPackage.objects.create(name="Standard", price=500.00)
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        
        today = timezone.now().date()
        self.sub = Subscription.objects.create(
            customer=self.profile,
            meal_package=self.package,
            start_date=today + timezone.timedelta(days=1),
            end_date=today + timezone.timedelta(days=30),
            time_slot=self.slot,
            diet_type='nonveg',
            cost_per_meal=10.00,
            selected_days=['Monday']
        )
        
        self.order = Order.objects.create(
            subscription=self.sub,
            order_date=timezone.now().date(),
            delivery_date=timezone.now().date(),
            status='pending'
        )
        
        self.kitchen_order = KitchenOrder.objects.create(order=self.order)
        self.list_url = '/api/v1/kitchen/orders/'

    def test_list_orders(self):
        response = self.client.get(self.list_url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) >= 1
        
    def test_claim_order(self):
        url = f'/api/v1/kitchen/orders/{self.kitchen_order.id}/claim/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.kitchen_order.refresh_from_db()
        assert self.kitchen_order.assigned_to == self.staff_user

    def test_start_preparation(self):
        url = f'/api/v1/kitchen/orders/{self.kitchen_order.id}/start_preparation/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.kitchen_order.refresh_from_db()
        assert self.kitchen_order.preparation_start_time is not None
        assert self.kitchen_order.order.status == 'preparing'

    def test_mark_ready(self):
        self.kitchen_order.preparation_start_time = timezone.now()
        self.kitchen_order.save()
        
        url = f'/api/v1/kitchen/orders/{self.kitchen_order.id}/mark_ready/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.kitchen_order.refresh_from_db()
        assert self.kitchen_order.preparation_end_time is not None
        assert self.kitchen_order.order.status == 'ready'

    def test_claim_conflict(self):
        other_staff = User.objects.create_user(username='other', password='password')
        self.kitchen_order.assigned_to = other_staff
        self.kitchen_order.save()
        
        url = f'/api/v1/kitchen/orders/{self.kitchen_order.id}/claim/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_409_CONFLICT
