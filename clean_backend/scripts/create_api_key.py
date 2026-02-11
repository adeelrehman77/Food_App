#!/usr/bin/env python3
"""
Create API Key

This script creates an API key for a user.

Usage:
    python3 create_api_key.py [username] [key_name] [days_valid]

Example:
    python3 create_api_key.py admin production_key 90
"""

import os
import sys
import django
import uuid
from datetime import datetime, timedelta

# Setup Django environment
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from django.contrib.auth.models import User
from django.utils import timezone
from apps.kitchen.models import APIKey
from cryptography.fernet import Fernet
from django.conf import settings

def create_api_key(username, key_name, days_valid=90):
    """Create an API key for a user."""
    try:
        # Get the user
        user = User.objects.get(username=username)
        
        # Generate a secure API key
        api_key = f"key_{uuid.uuid4().hex}"
        
        # Set expiration date
        expires_at = timezone.now() + timedelta(days=days_valid)
        
        # Encrypt the key
        encryption_key = getattr(settings, 'ENCRYPTION_KEY', None)
        if not encryption_key:
            print("Error: ENCRYPTION_KEY not set in settings")
            return None
        
        fernet = Fernet(encryption_key.encode())
        encrypted_key = fernet.encrypt(api_key.encode()).decode()
        
        # Create the API key object
        key_obj = APIKey.objects.create(
            user=user,
            key=encrypted_key,
            name=key_name,
            is_active=True,
            expires_at=expires_at
        )
        
        print(f"\nAPI Key created successfully!")
        print(f"Username: {username}")
        print(f"Key Name: {key_name}")
        print(f"API Key: {api_key}")
        print(f"Expires: {expires_at.strftime('%Y-%m-%d')}")
        print("\nIMPORTANT: Store this key securely. It cannot be retrieved later.\n")
        
        return api_key
    
    except User.DoesNotExist:
        print(f"Error: User '{username}' does not exist")
        return None
    except Exception as e:
        print(f"Error: {str(e)}")
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 create_api_key.py [username] [key_name] [days_valid]")
        print("Example: python3 create_api_key.py admin production_key 90")
        sys.exit(1)
    
    username = sys.argv[1]
    key_name = sys.argv[2]
    days_valid = int(sys.argv[3]) if len(sys.argv) > 3 else 90
    
    create_api_key(username, key_name, days_valid) 