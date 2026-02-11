#!/usr/bin/env python3
"""
Setup Database

This script sets up the database with initial data.

Usage:
    python3 setup_database.py
"""

import os
import sys
import django

# Setup Django environment
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from django.core.management import call_command
from django.contrib.auth.models import User, Group
from django.db import connection

def setup_database():
    """Setup the database with initial data."""
    print("Setting up database...")
    
    # Run migrations
    print("Running migrations...")
    call_command('migrate')
    
    # Create superuser if it doesn't exist
    if not User.objects.filter(is_superuser=True).exists():
        print("Creating superuser...")
        call_command('createsuperuser', interactive=False)
    
    # Create groups
    print("Creating groups...")
    groups = [
        'Kitchen Staff',
        'Driver',
        'Manager',
        'Customer'
    ]
    
    for group_name in groups:
        group, created = Group.objects.get_or_create(name=group_name)
        if created:
            print(f"Created group: {group_name}")
    
    # Create initial data
    print("Creating initial data...")
    create_initial_data()
    
    print("Database setup completed successfully!")

def create_initial_data():
    """Create initial data for the application."""
    from apps.main.models import Category, TimeSlot
    from apps.inventory.models import UnitOfMeasure
    
    # Create categories
    categories = [
        {'name': 'Veg', 'description': 'Vegetarian meals'},
        {'name': 'Non-Veg', 'description': 'Non-vegetarian meals'},
        {'name': 'Vegan', 'description': 'Vegan meals'},
        {'name': 'Gluten-Free', 'description': 'Gluten-free meals'},
    ]
    
    for cat_data in categories:
        category, created = Category.objects.get_or_create(
            name=cat_data['name'],
            defaults={'description': cat_data['description']}
        )
        if created:
            print(f"Created category: {category.name}")
    
    # Create time slots
    time_slots = [
        {'name': 'breakfast', 'time': '7:00 AM - 9:00 AM', 'start_time': '07:00', 'end_time': '09:00'},
        {'name': 'lunch', 'time': '12:00 PM - 2:00 PM', 'start_time': '12:00', 'end_time': '14:00'},
        {'name': 'dinner', 'time': '7:00 PM - 9:00 PM', 'start_time': '19:00', 'end_time': '21:00'},
    ]
    
    for slot_data in time_slots:
        time_slot, created = TimeSlot.objects.get_or_create(
            name=slot_data['name'],
            defaults={
                'time': slot_data['time'],
                'start_time': slot_data['start_time'],
                'end_time': slot_data['end_time']
            }
        )
        if created:
            print(f"Created time slot: {time_slot.name}")
    
    # Create units of measure
    units = [
        {'name': 'Kilogram', 'abbreviation': 'kg', 'category': 'weight', 'conversion_factor': 1.0},
        {'name': 'Gram', 'abbreviation': 'g', 'category': 'weight', 'conversion_factor': 0.001},
        {'name': 'Liter', 'abbreviation': 'L', 'category': 'volume', 'conversion_factor': 1.0},
        {'name': 'Milliliter', 'abbreviation': 'ml', 'category': 'volume', 'conversion_factor': 0.001},
        {'name': 'Piece', 'abbreviation': 'pc', 'category': 'unit', 'conversion_factor': 1.0},
        {'name': 'Pack', 'abbreviation': 'pack', 'category': 'unit', 'conversion_factor': 1.0},
    ]
    
    for unit_data in units:
        unit, created = UnitOfMeasure.objects.get_or_create(
            name=unit_data['name'],
            defaults={
                'abbreviation': unit_data['abbreviation'],
                'category': unit_data['category'],
                'conversion_factor': unit_data['conversion_factor']
            }
        )
        if created:
            print(f"Created unit: {unit.name}")

if __name__ == "__main__":
    setup_database() 