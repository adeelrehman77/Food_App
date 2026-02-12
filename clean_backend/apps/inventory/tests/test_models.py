import pytest
from decimal import Decimal
from apps.inventory.models import UnitOfMeasure, InventoryItem

@pytest.mark.django_db
class TestInventoryModels:
    def test_create_unit(self):
        unit = UnitOfMeasure.objects.create(
            name="Kilogram", abbreviation="kg", category="weight", conversion_factor=1.0
        )
        assert str(unit) == "Kilogram (kg)"

    def test_create_item(self):
        unit = UnitOfMeasure.objects.create(name="Kg", abbreviation="kg", category="weight")
        item = InventoryItem.objects.create(
            name="Rice", unit=unit, current_stock=Decimal("10.00"), min_stock_level=Decimal("5.00")
        )
        assert item.name == "Rice"
        assert item.is_low_stock is False
        
        # Make low stock
        item.current_stock = Decimal("4.00")
        item.save()
        assert item.is_low_stock is True
        
        # Test exact match
        item.current_stock = Decimal("5.00")
        item.save()
        assert item.is_low_stock is True # <= min_stock_level
