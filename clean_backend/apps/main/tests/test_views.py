import pytest
from decimal import Decimal
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from apps.main.models import (
    CustomerProfile, Category, MenuItem, MealPackage, 
    MealSlot, Subscription
)

User = get_user_model()

@pytest.mark.django_db
class TestCustomerAuthAPI:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.register_url = '/api/v1/customer/auth/register/'
        self.login_url = '/api/v1/customer/auth/login/'

    def test_register_customer(self):
        data = {
            'phone': '9876543210',
            'password': 'password123',
            'first_name': 'New',
            'last_name': 'User'
        }
        response = self.client.post(self.register_url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert 'tokens' in response.data
        assert User.objects.filter(username='9876543210').exists()
        assert CustomerProfile.objects.filter(phone='9876543210').exists()

    def test_login_customer(self):
        user = User.objects.create_user(username='testlogin', password='password123')
        CustomerProfile.objects.create(user=user, phone='testlogin')
        
        data = {
            'phone': 'testlogin',
            'password': 'password123'
        }
        response = self.client.post(self.login_url, data)
        assert response.status_code == status.HTTP_200_OK
        assert 'tokens' in response.data

@pytest.mark.django_db
class TestPublicMenuAPI:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.url = '/api/v1/customer/menu/'
        
        self.cat1 = Category.objects.create(name="Starters")
        self.item1 = MenuItem.objects.create(
            name="Salad", price=Decimal("15.00"), category=self.cat1, is_available=True
        )
        self.item2 = MenuItem.objects.create(
            name="Soup", price=Decimal("12.00"), category=self.cat1, is_available=False
        )

    def test_list_public_menu(self):
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1 # Only available items
        assert response.data[0]['name'] == "Salad"

@pytest.mark.django_db
class TestCustomerSubscriptionAPI:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_user(username='subuser', password='password123')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='subuser')
        self.client.force_authenticate(user=self.user)
        
        self.package = MealPackage.objects.create(
            name="Standard", price=Decimal("500.00"), duration_days=30
        )
        self.meal_slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.url = '/api/v1/customer/subscriptions/'

    def test_create_subscription(self):
        # We need generic menu setup or minimal valid data
        # SubscriptionSerializer validates data.
        # Assuming minimal fields required by serializer validtion
        from django.utils import timezone
        start_date = timezone.now().date() + timezone.timedelta(days=2)
        end_date = start_date + timezone.timedelta(days=30)
        
        data = {
            'meal_package': self.package.id,
            'start_date': start_date,
            'end_date': end_date,
            'time_slot': self.meal_slot.id,
            'selected_days': ['Monday', 'Tuesday'],
            'diet_type': 'veg',
            # 'customer' is handled by perform_create
        }
        response = self.client.post(self.url, data, format='json')
        if response.status_code != 201:
            print(response.data)
        assert response.status_code == status.HTTP_201_CREATED
        assert Subscription.objects.filter(customer=self.profile).exists()
