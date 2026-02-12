import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.driver.models import Zone, Route

User = get_user_model()

@pytest.mark.django_db
class TestZoneViewSet:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.user = User.objects.create_superuser(username='admin', password='pw', email='admin@test.com')
        self.client.force_authenticate(user=self.user)
        self.zone = Zone.objects.create(name="Downtown", delivery_fee=15.00)

    def test_list_zones(self):
        res = self.client.get('/api/v1/driver/zones/')
        assert res.status_code == 200
        assert len(res.data['results']) >= 1

    def test_create_zone(self):
        data = {'name': 'JLT', 'delivery_fee': '12.00', 'estimated_delivery_time': 40}
        res = self.client.post('/api/v1/driver/zones/', data, format='json')
        assert res.status_code == 201
        assert Zone.objects.filter(name='JLT').exists()

    def test_update_zone(self):
        data = {'delivery_fee': '20.00'}
        res = self.client.patch(f'/api/v1/driver/zones/{self.zone.id}/', data, format='json')
        assert res.status_code == 200
        self.zone.refresh_from_db()
        assert self.zone.delivery_fee == 20.00
