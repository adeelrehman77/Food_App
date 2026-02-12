import pytest
from decimal import Decimal
from apps.organizations.models import ServicePlan

@pytest.mark.django_db
class TestServicePlan:
    def setup_method(self):
        self.plan = ServicePlan.objects.create(
            name="Pro Plan",
            tier="pro",
            price_monthly=Decimal("100.00"),
            max_menu_items=50,
            has_analytics=True,
            features={'custom_branding': True}
        )

    def test_has_feature(self):
        # Boolean field
        assert self.plan.has_feature('analytics') is True
        assert self.plan.has_feature('whatsapp_notifications') is False
        
        # JSON field
        assert self.plan.has_feature('custom_branding') is True
        assert self.plan.has_feature('unknown') is False

    def test_check_limit(self):
        # max_menu_items = 50
        assert self.plan.check_limit('menu_items', 49) is True
        assert self.plan.check_limit('menu_items', 50) is False # < limit
        
        # Unlimited
        self.plan.max_customers = 0
        self.plan.save()
        assert self.plan.check_limit('customers', 10000) is True
