import pytest
from django.utils import timezone
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.driver.models import DeliveryStatus, DeliveryDriver, DeliveryAssignment
from apps.main.models import Subscription, CustomerProfile, MealSlot, MealPackage

User = get_user_model()

@pytest.mark.django_db
class TestDriverViews:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_user(username='driver', password='pw', email='driver@test.com')
        self.client.force_authenticate(user=self.user)
        
        # Setup data
        self.driver_profile = DeliveryDriver.objects.create(
            name="Driver John", 
            phone="123456789", 
            email='driver@test.com' # Must match user email
        )
        
        # Subscription & Delivery Status
        self.customer = User.objects.create_user(username='cust', password='pw')
        self.profile = CustomerProfile.objects.create(user=self.customer)
        self.pkg = MealPackage.objects.create(name="Std", price=100)
        self.slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.sub = Subscription.objects.create(
            customer=self.profile, meal_package=self.pkg, time_slot=self.slot,
            start_date=timezone.now().date(), 
            end_date=timezone.now().date() + timezone.timedelta(days=30), # 30 days > minimum
            selected_days=['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        )
        self.status = DeliveryStatus.objects.create(
            subscription=self.sub,
            date=timezone.now().date(),
            status='out_for_delivery'
        )
        
        # Assignment
        self.assignment = DeliveryAssignment.objects.create(
            delivery_status=self.status,
            driver=self.driver_profile
        )

    def test_list_deliveries(self):
        # Assert data exists in DB
        assert DeliveryAssignment.objects.count() == 1
        assert DeliveryStatus.objects.filter(date=timezone.now().date()).count() == 1
        
        response = self.client.get('/api/v1/driver/deliveries/')
        assert response.status_code == 200
        
        results = response.data['results'] if 'results' in response.data else response.data
        if len(results) == 0:
            print(f"DEBUG: Assignments count: {DeliveryAssignment.objects.count()}")
            print(f"DEBUG: Status date: {self.status.date}, Now date: {timezone.now().date()}")
            print(f"DEBUG: Driver email: {self.driver_profile.email}, User email: {self.user.email}")
            
        assert len(results) >= 1
        assert results[0]['id'] == self.assignment.id

    def test_update_status(self):
        url = f'/api/v1/driver/deliveries/{self.assignment.id}/update_status/'
        
        # Invalid status
        res = self.client.post(url, {'status': 'pending'}, format='json')
        assert res.status_code == 400
        
        # Valid status
        res = self.client.post(url, {'status': 'delivered'}, format='json')
        assert res.status_code == 200
        self.status.refresh_from_db()
        assert self.status.status == 'delivered'

    def test_add_note(self):
        url = f'/api/v1/driver/deliveries/{self.assignment.id}/add_note/'
        
        # Missing note
        res = self.client.post(url, {}, format='json')
        assert res.status_code == 400
        
        # Valid note
        res = self.client.post(url, {'note': 'Door locked'}, format='json')
        assert res.status_code == 200
        self.status.refresh_from_db()
        assert 'Door locked' in self.status.driver_notes
