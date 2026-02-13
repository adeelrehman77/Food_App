"""
Utility functions for delivery and driver assignment.
"""
from django.db.models import Q
from apps.driver.models import DeliveryDriver, Zone


def get_available_driver_for_zone(zone):
    """
    Get an available driver for a given zone.
    
    Priority:
    1. Active drivers assigned to this zone
    2. Drivers with least current assignments for today
    
    Returns DeliveryDriver instance or None if no driver available.
    """
    if zone is None:
        return None
    
    # Get active drivers assigned to this zone
    available_drivers = DeliveryDriver.objects.filter(
        zones=zone,
        is_active=True
    ).distinct()
    
    if not available_drivers.exists():
        return None
    
    # For now, return the first available driver
    # TODO: Implement load balancing (driver with least assignments)
    return available_drivers.first()


def assign_driver_to_order(order):
    """
    Automatically assign a driver to an order based on its delivery zone.
    
    Returns the assigned DeliveryDriver or None if no driver available.
    """
    # Get zone from subscription's address based on meal slot
    subscription = order.subscription
    meal_slot = subscription.time_slot
    
    # Determine which address to use (lunch or dinner)
    if meal_slot:
        meal_slot_name = getattr(meal_slot, 'name', '').lower()
        meal_slot_code = getattr(meal_slot, 'code', '').lower()
        
        if 'lunch' in meal_slot_name or 'lunch' in meal_slot_code:
            address = subscription.lunch_address
        elif 'dinner' in meal_slot_name or 'dinner' in meal_slot_code:
            address = subscription.dinner_address
        else:
            address = subscription.lunch_address or subscription.dinner_address
    else:
        address = subscription.lunch_address or subscription.dinner_address
    
    if not address or not address.zone:
        return None
    
    return get_available_driver_for_zone(address.zone)
