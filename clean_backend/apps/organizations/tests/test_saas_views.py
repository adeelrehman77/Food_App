import pytest
from unittest.mock import patch, MagicMock
from decimal import Decimal
from django.utils import timezone
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from apps.organizations.models import ServicePlan
from apps.users.models import Tenant, UserProfile
from apps.organizations.models_saas import TenantSubscription, TenantInvoice

User = get_user_model()

@pytest.mark.django_db
class TestSaaSViews:
    def setup_method(self):
        self.client = APIClient(HTTP_USER_AGENT='Mozilla/5.0')
        self.superuser = User.objects.create_superuser(username='admin', password='password', email='admin@test.com')
        self.client.force_authenticate(user=self.superuser)
        
        self.plan = ServicePlan.objects.create(name="Pro", price_monthly=100.00, trial_days=14, is_active=True)
        self.tenant = Tenant.objects.create(name="Test Kitchen", subdomain="testkitchen", is_active=True)
        self.sub = TenantSubscription.objects.create(
            tenant=self.tenant, plan=self.plan, status='active', 
            current_period_start=timezone.now().date(),
            current_period_end=timezone.now().date()
        )

    def test_list_plans(self):
        res = self.client.get('/api/saas/plans/')
        assert res.status_code == 200
        assert len(res.data['results']) >= 1

    @patch('django.core.management.call_command')
    @patch('apps.organizations.views_saas.TenantViewSet._migrate_tenant_db')
    @patch('apps.organizations.views_saas.TenantViewSet._provision_tenant_db')
    @patch('apps.organizations.serializers.TenantCreateSerializer.validate_subdomain')
    def test_provision_tenant(self, mock_validate, mock_provision, mock_migrate, mock_call_command):
        # Allow validation to pass simply returning the value
        mock_validate.side_effect = lambda x: x
        import uuid
        
        # Mock DB creation return value (db_name)
        unique_sub = f"tenant_{uuid.uuid4().hex[:8]}"
        mock_provision.return_value = f"tenant_{unique_sub}"
        
        data = {
            'name': 'New Tenant',
            'subdomain': unique_sub,
            'admin_email': 'new@tenant.com',
            'admin_password': 'password123',
            'plan_id': self.plan.id
        }
        res = self.client.post('/api/saas/tenants/', data, format='json')
        
        # Assert response code first
        if res.status_code != 201:
            print(f"DEBUG: Response {res.status_code} - {res.data}")
        assert res.status_code == 201
        assert res.data['name'] == 'New Tenant'
        assert res.data['subdomain'] == unique_sub
        
        # Verify Tenant created
        assert Tenant.objects.filter(subdomain=unique_sub).exists()
        tenant = Tenant.objects.get(subdomain=unique_sub)
        assert tenant.service_plan == self.plan
        
        # Verify admin user created
        assert User.objects.filter(email='new@tenant.com').exists()
        
        # Verify DB mocks called
        mock_provision.assert_called_once()
        mock_migrate.assert_called_once_with(tenant, f"tenant_{unique_sub}")

    def test_update_tenant(self):
        res = self.client.patch(f'/api/saas/tenants/{self.tenant.id}/', {'is_active': False}, format='json')
        assert res.status_code == 200
        self.tenant.refresh_from_db()
        assert not self.tenant.is_active

    def test_suspend_activate_tenant(self):
        # Suspend
        res = self.client.post(f'/api/saas/tenants/{self.tenant.id}/suspend/', {}, format='json')
        assert res.status_code == 200
        self.tenant.refresh_from_db()
        assert not self.tenant.is_active
        self.sub.refresh_from_db()
        assert self.sub.status == 'suspended'
        
        # Activate
        res = self.client.post(f'/api/saas/tenants/{self.tenant.id}/activate/', {}, format='json')
        assert res.status_code == 200
        self.tenant.refresh_from_db()
        assert self.tenant.is_active
        self.sub.refresh_from_db()
        assert self.sub.status == 'active'

    def test_invoice_mark_paid(self):
        invoice = TenantInvoice.objects.create(
            tenant=self.tenant, subscription=self.sub, status='pending', amount=Decimal('100.00'),
            period_start=timezone.now().date(), period_end=timezone.now().date(),
            due_date=timezone.now().date() + timezone.timedelta(days=7)
        )
        res = self.client.post(f'/api/saas/invoices/{invoice.id}/mark_paid/', {}, format='json')
        assert res.status_code == 200
        invoice.refresh_from_db()
        assert invoice.status == 'paid'
        assert invoice.paid_at is not None

    def test_platform_analytics(self):
        res = self.client.get('/api/saas/analytics/')
        assert res.status_code == 200
        assert 'total_revenue_monthly' in res.data
