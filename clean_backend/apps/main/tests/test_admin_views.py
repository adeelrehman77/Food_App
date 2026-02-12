import pytest
import datetime
from decimal import Decimal
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.main.models import (
    CustomerProfile, Order, DailyMenu, MealSlot, MealPackage, Subscription, 
    Menu, MenuItem, Category
)
from apps.inventory.models import InventoryItem

User = get_user_model()

@pytest.mark.django_db
class TestAdminDashboard:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin', password='password')
        self.client.force_authenticate(user=self.admin)
        self.url = '/api/v1/dashboard/summary/'

    def test_dashboard_summary(self):
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        assert 'orders' in response.data
        assert 'revenue' in response.data

@pytest.mark.django_db
class TestOrderAdmin:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin', password='password')
        self.client.force_authenticate(user=self.admin)
        
        # Create dependencies
        self.customer_user = User.objects.create_user(username='cust', password='pw')
        self.profile = CustomerProfile.objects.create(user=self.customer_user, phone='123')
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Std", price=Decimal('100'))
        
        d1 = timezone.now().date()
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=d1, end_date=d1 + datetime.timedelta(days=30),
            time_slot=self.slot,
            selected_days=['Monday']
        )
        self.order = Order.objects.create(
            subscription=self.sub, order_date=d1, delivery_date=d1, status='pending'
        )
        self.list_url = '/api/v1/orders/'
        self.detail_url = f'/api/v1/orders/{self.order.id}/'

    def test_list_orders(self):
        response = self.client.get(self.list_url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['results']) >= 1

    def test_update_status(self):
        url = f'{self.detail_url}update_status/'
        response = self.client.post(url, {'status': 'confirmed'}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.order.refresh_from_db()
        assert self.order.status == 'confirmed'

    def test_invalid_status_transition(self):
        url = f'{self.detail_url}update_status/'
        response = self.client.post(url, {'status': 'delivered'}, format='json') # pending -> delivered invalid
        assert response.status_code == status.HTTP_400_BAD_REQUEST

@pytest.mark.django_db
class TestDailyMenuAdmin:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin', password='password')
        self.client.force_authenticate(user=self.admin)
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.menu_date = timezone.now().date()
        self.daily_menu = DailyMenu.objects.create(
            menu_date=self.menu_date, meal_slot=self.slot, status='draft',
            created_by=self.admin
        )
        
        # Add item to menu
        self.cat = Category.objects.create(name="Main")
        self.item = MenuItem.objects.create(name="Chicken", category=self.cat, price=10)
        self.daily_menu.items.create(master_item=self.item)
        
        self.url = f'/api/v1/daily-menus/{self.daily_menu.id}/'

    def test_publish_menu(self):
        url = f'{self.url}publish/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.daily_menu.refresh_from_db()
        assert self.daily_menu.status == 'published'
        
    def test_close_menu(self):
        url = f'{self.url}close/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.daily_menu.refresh_from_db()
        assert self.daily_menu.status == 'closed'

@pytest.mark.django_db
class TestCustomerAdmin:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin_cust', password='password')
        self.client.force_authenticate(user=self.admin)
        from apps.main.models import CustomerProfile
        self.url = '/api/v1/customers/'

    def test_list_customers(self):
        User.objects.create_user(username='new_cust', password='pw')
        CustomerProfile.objects.create(user=User.objects.get(username='new_cust'), phone='111')
        response = self.client.get(self.url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['results']) >= 1

@pytest.mark.django_db
class TestRegistrationRequestAdmin:
    def setup_method(self):
        from apps.main.models import CustomerRegistrationRequest
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin_reg', password='password')
        self.client.force_authenticate(user=self.admin)
        self.req = CustomerRegistrationRequest.objects.create(
            name="New Guy", contact_number="12345678", 
            meal_selection="lunch", meal_type="veg", quantity=1
        )
        self.url = f'/api/v1/registration-requests/{self.req.id}/'

    def test_approve_request(self):
        url = f'{self.url}approve/'
        response = self.client.post(url, {'admin_notes': 'Ok'}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.req.refresh_from_db()
        assert self.req.status == 'approved'
        assert User.objects.filter(username__contains='cust_12345678').exists()

    def test_reject_request(self):
        url = f'{self.url}reject/'
        response = self.client.post(url, {'reason': 'Bad'}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.req.refresh_from_db()
        assert self.req.status == 'rejected'

@pytest.mark.django_db
class TestStaffUserAdmin:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin_staff', password='password')
        self.client.force_authenticate(user=self.admin)
        self.url = '/api/v1/staff/'

    def test_create_staff(self):
        data = {
            'username': 'new_staff', 'email': 's@s.com', 'password': 'password123',
            'role': 'manager'
        }
        response = self.client.post(self.url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        u = User.objects.get(username='new_staff')
        assert u.is_staff
        assert u.groups.filter(name='Manager').exists()

@pytest.mark.django_db
class TestSubscriptionAdmin:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.admin = User.objects.create_superuser(username='admin_sub', password='password')
        self.client.force_authenticate(user=self.admin)
        
        self.user = User.objects.create_user(username='sub_cust', password='pw')
        self.profile = CustomerProfile.objects.create(user=self.user, phone='999')
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(name="Std", price=Decimal('100'))
        
        d1 = timezone.now().date()
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.package,
            start_date=d1, end_date=d1 + datetime.timedelta(days=30),
            time_slot=self.slot, status='active',
            selected_days=['Monday']
        )
        self.url = f'/api/v1/subscriptions-admin/{self.sub.id}/'

    def test_pause_subscription(self):
        url = f'{self.url}pause/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.sub.refresh_from_db()
        assert self.sub.status == 'paused'

    def test_cancel_subscription(self):
        url = f'{self.url}cancel/'
        response = self.client.post(url, {}, format='json')
        assert response.status_code == status.HTTP_200_OK
        self.sub.refresh_from_db()
        assert self.sub.status == 'cancelled'
