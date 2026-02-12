import pytest
from datetime import date, timedelta
from decimal import Decimal
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.core.exceptions import ValidationError
from apps.main.models import (
    CustomerProfile, Category, MenuItem, MealSlot, DailyMenu, 
    MealPackage, Subscription, Address
)

User = get_user_model()

@pytest.mark.django_db
class TestCustomerProfile:
    def test_create_profile(self):
        user = User.objects.create_user(username="customer", password="password")
        profile = CustomerProfile.objects.create(
            user=user,
            phone="1234567890",
            tenant_id=1
        )
        assert profile.user == user
        assert profile.phone == "1234567890"
        assert profile.tenant_id == 1
        assert str(profile) == f"[Tenant #1] customer ({profile.phone})"

@pytest.mark.django_db
class TestMenuItem:
    def test_create_menu_item(self):
        category = Category.objects.create(name="Main")
        item = MenuItem.objects.create(
            name="Chicken Curry",
            description="Delicious curry",
            price=Decimal("25.00"),
            category=category,
            diet_type="nonveg"
        )
        assert item.name == "Chicken Curry"
        assert item.price == Decimal("25.00")
        assert item.category == category
        assert item.diet_type == "nonveg"
        assert str(item) == "Chicken Curry (Non-Vegetarian)"

@pytest.mark.django_db
class TestSubscription:
    def setup_method(self):
        self.user = User.objects.create_user(username="subuser", password="password")
        self.profile = CustomerProfile.objects.create(user=self.user)
        self.meal_slot = MealSlot.objects.create(name="Lunch", code="lunch")
        self.package = MealPackage.objects.create(
            name="Standard",
            price=Decimal("500.00"),
            meals_per_day=1,
            duration="monthly",
            duration_days=30
        )

    def test_create_valid_subscription(self):
        start_date = timezone.now().date() + timedelta(days=1)
        end_date = start_date + timedelta(days=30)
        
        # Create a menu with price
        menu = pytest.importorskip("apps.main.models").Menu.objects.create(name="Monthly Plan", price=Decimal("500.00"))

        sub = Subscription(
            customer=self.profile,
            meal_package=self.package,
            start_date=start_date,
            end_date=end_date,
            time_slot=self.meal_slot,
            selected_days=['Monday', 'Wednesday', 'Friday'],
            diet_type='nonveg',
            cost_per_meal=Decimal("0.00") # Start with 0
        )
        sub.full_clean()
        sub.save()
        
        # Add menu and save again to calculate cost
        sub.menus.add(menu)
        sub.save()
        
        assert sub.status == 'pending'
        assert sub.customer == self.profile
        assert sub.total_cost > 0 # Should be calculated based on menu price and days

    def test_subscription_dates_validation(self):
        start_date = timezone.now().date() + timedelta(days=1)
        end_date = start_date - timedelta(days=1) # End before start
        
        sub = Subscription(
            customer=self.profile,
            meal_package=self.package,
            start_date=start_date,
            end_date=end_date,
            time_slot=self.meal_slot,
            selected_days=['Monday']
        )
        with pytest.raises(ValidationError) as excinfo:
            sub.full_clean()
        assert 'End date must be after start date' in str(excinfo.value)

    def test_subscription_past_start_date(self):
        start_date = timezone.now().date() - timedelta(days=1) # Past date
        end_date = start_date + timedelta(days=30)
        
        sub = Subscription(
            customer=self.profile,
            meal_package=self.package,
            start_date=start_date,
            end_date=end_date,
            time_slot=self.meal_slot,
            selected_days=['Monday']
        )
        with pytest.raises(ValidationError) as excinfo:
            sub.full_clean()
        assert 'Start date cannot be in the past' in str(excinfo.value)
