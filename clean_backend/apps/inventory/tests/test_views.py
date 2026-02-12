import pytest
from unittest.mock import patch
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.inventory.models import InventoryItem, UnitOfMeasure

User = get_user_model()

@pytest.mark.django_db
class TestInventoryViewSet:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_superuser(username='staff', password='pw', email='staff@test.com')
        self.client.force_authenticate(user=self.user)
        
        # Setup data
        self.unit = UnitOfMeasure.objects.create(name='Kg', abbreviation='kg')
        self.item = InventoryItem.objects.create(
            name='Rice', 
            unit=self.unit,
            current_stock=10,
            min_stock_level=5,
            cost_per_unit=5.0
        )

    def test_list_items(self):
        with patch('core.permissions.plan_limits.PlanFeatureInventory.has_permission', return_value=True):
            res = self.client.get('/api/v1/inventory/items/')
            assert res.status_code == 200
            assert len(res.data['results']) >= 1

    def test_adjust_stock(self):
        url = f'/api/v1/inventory/items/{self.item.id}/adjust_stock/'
        
        with patch('core.permissions.plan_limits.PlanFeatureInventory.has_permission', return_value=True):
            # Add stock
            res = self.client.post(url, {'quantity': 5}, format='json')
            assert res.status_code == 200
            self.item.refresh_from_db()
            assert self.item.current_stock == 15
            
            # Subtract stock
            res = self.client.post(url, {'quantity': -5}, format='json')
            assert res.status_code == 200
            self.item.refresh_from_db()
            assert self.item.current_stock == 10
            
            # Invalid (below zero)
            res = self.client.post(url, {'quantity': -15}, format='json')
            assert res.status_code == 400

    def test_low_stock(self):
        with patch('core.permissions.plan_limits.PlanFeatureInventory.has_permission', return_value=True):
            res = self.client.get('/api/v1/inventory/items/low_stock/')
            assert res.status_code == 200
            assert len(res.data) == 0
            
            # Make it low
            self.item.current_stock = 4
            self.item.save()
            
            res = self.client.get('/api/v1/inventory/items/low_stock/')
            assert res.status_code == 200
            assert len(res.data) == 1
