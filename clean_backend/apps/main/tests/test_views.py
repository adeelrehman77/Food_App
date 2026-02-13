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
@pytest.mark.django_db
class TestCustomerOrderAPI:
    def setup_method(self):
        import datetime
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_user(username='orderuser', password='password123')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='orderuser')
        self.client.force_authenticate(user=self.user)
        self.url = '/api/v1/customer/orders/'
        
        # Setup subscription and order
        from apps.main.models import Subscription, Order, MealSlot, MealPackage, Address, WalletTransaction
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Std", price=Decimal('100.00'))
        
        today = datetime.date.today()
        d1 = today + datetime.timedelta(days=1)
        d30 = today + datetime.timedelta(days=30)
        
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=d1, end_date=d30,
            time_slot=self.slot, selected_days=['Monday']
        )
        self.order = Order.objects.create(
            subscription=self.sub, order_date=d1, delivery_date=d1,
            status='pending'
        )

    def test_list_orders(self):
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        # Handle pagination
        results = response.data['results'] if 'results' in response.data else response.data
        assert len(results) >= 1
        assert results[0]['status'] == 'pending'

    def test_track_order(self):
        url = f'{self.url}{self.order.id}/track/'
        response = self.client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert 'delivery_status' in response.data

@pytest.mark.django_db
class TestCustomerWalletAPI:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_user(username='walletuser', password='password123')
        self.profile = CustomerProfile.objects.create(
            user=self.user, phone='walletuser', wallet_balance=Decimal('50.00')
        )
        self.client.force_authenticate(user=self.user)
        self.url = '/api/v1/customer/wallet/'

    def test_get_wallet(self):
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['balance'] == '50.00'

    def test_topup(self):
        data = {'amount': '100.00'}
        response = self.client.post(self.url + 'topup/', data, format='json')
        assert response.status_code == status.HTTP_200_OK
        assert response.data['balance'] == '150.00'
        self.profile.refresh_from_db()
        assert self.profile.wallet_balance == Decimal('150.00')

@pytest.mark.django_db
class TestCustomerAddressAPI:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_user(username='addressuser', password='password123')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='addressuser')
        self.client.force_authenticate(user=self.user)
        self.url = '/api/v1/customer/addresses/'

    def test_create_address(self):
        data = {
            'street': '123 Main St',
            'city': 'Dubai',
            'building_name': 'Burj Khalifa',
            'is_default': True
        }
        response = self.client.post(self.url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['street'] == '123 Main St'
        
    def test_list_addresses(self):
        from apps.main.models import Address
        Address.objects.create(customer=self.profile, street='Old St', building_name='Old Bldg')
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) >= 1
