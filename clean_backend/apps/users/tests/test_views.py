import pytest
import json
from django.urls import reverse
from django.test import Client
from apps.users.models import Tenant

@pytest.mark.django_db
class TestDiscoverTenantView:
    def setup_method(self):
        self.client = Client(HTTP_USER_AGENT='Mozilla/5.0 (Test Client)')
        self.url = '/api/discover/'

    def test_discover_tenant_success(self):
        Tenant.objects.create(
            name="Test Kitchen",
            subdomain="test-kitchen",
            schema_name="test_kitchen",
            is_active=True
        )
        # The view expects JSON body with 'kitchen_code'
        # content_type='application/json' is required by RequestValidationMiddleware
        response = self.client.post(
            self.url,
            data=json.dumps({'kitchen_code': 'test-kitchen'}),
            content_type='application/json'
        )
        assert response.status_code == 200
        data = response.json()
        assert data['tenant_id'] == 'test-kitchen'
        assert data['name'] == 'Test Kitchen'

    def test_discover_tenant_not_found(self):
        response = self.client.post(
            self.url,
            data=json.dumps({'kitchen_code': 'non-existent'}),
            content_type='application/json'
        )
        assert response.status_code == 404
        assert response.json()['error'] == 'Kitchen not found'

    def test_discover_tenant_inactive(self):
        Tenant.objects.create(
            name="Inactive Kitchen",
            subdomain="inactive",
            schema_name="inactive",
            is_active=False
        )
        response = self.client.post(
            self.url,
            data=json.dumps({'kitchen_code': 'inactive'}),
            content_type='application/json'
        )
        assert response.status_code == 403
        assert response.json()['error'] == 'This kitchen is currently inactive'

    def test_discover_tenant_missing_code(self):
        response = self.client.post(
            self.url,
            data=json.dumps({}), # Empty JSON
            content_type='application/json'
        )
        assert response.status_code == 400
        assert response.json()['error'] == 'Kitchen code is required'

    def test_discover_tenant_invalid_json(self):
        response = self.client.post(
            self.url,
            data="invalid-json",
            content_type='application/json'
        )
        assert response.status_code == 400
        # Middleware catches invalid JSON before the view
        assert response.json()['error'] in ['Invalid request data', 'Invalid JSON']
