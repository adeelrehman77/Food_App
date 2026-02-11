from rest_framework import permissions
from django.contrib.auth.models import Group

class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to edit it.
    """
    
    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed for any request,
        # so we'll always allow GET, HEAD or OPTIONS requests.
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions are only allowed to the owner of the snippet.
        return obj.user == request.user

class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Custom permission to only allow owners or admins to access an object.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin can access everything
        if request.user.is_staff:
            return True
        
        # Owner can access their own objects
        if hasattr(obj, 'user'):
            return obj.user == request.user
        elif hasattr(obj, 'customer'):
            return obj.customer.user == request.user
        
        return False

class IsKitchenStaff(permissions.BasePermission):
    """
    Custom permission to only allow kitchen staff.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name='Kitchen Staff').exists())
        )

class IsDriver(permissions.BasePermission):
    """
    Custom permission to only allow drivers.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name='Driver').exists())
        )

class IsManager(permissions.BasePermission):
    """
    Custom permission to only allow managers.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name='Manager').exists())
        )

class IsCustomer(permissions.BasePermission):
    """
    Custom permission to only allow customers.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            not request.user.is_staff and
            not request.user.groups.filter(
                name__in=['Kitchen Staff', 'Driver', 'Manager']
            ).exists()
        )

class HasAPIKeyOrIsAuthenticated(permissions.BasePermission):
    """
    Custom permission to allow access with API key or authentication.
    """
    
    def has_permission(self, request, view):
        # Check if API key is present
        if hasattr(request, 'api_key') and request.api_key:
            return True
        
        # Fall back to authentication
        return request.user.is_authenticated

class IsReadOnlyOrHasAPIKey(permissions.BasePermission):
    """
    Custom permission to allow read access to anyone, but write access only with API key.
    """
    
    def has_permission(self, request, view):
        # Read permissions are allowed for any request
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions require API key
        return hasattr(request, 'api_key') and request.api_key is not None

class IsSubscriptionOwner(permissions.BasePermission):
    """
    Custom permission to only allow subscription owners to access their subscriptions.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin can access everything
        if request.user.is_staff:
            return True
        
        # Check if user owns the subscription
        return obj.customer.user == request.user

class IsDeliveryOwner(permissions.BasePermission):
    """
    Custom permission to only allow delivery owners to access their deliveries.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin can access everything
        if request.user.is_staff:
            return True
        
        # Check if user owns the delivery
        return obj.subscription.customer.user == request.user

class IsKitchenOrderOwner(permissions.BasePermission):
    """
    Custom permission to only allow kitchen order owners to access their orders.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin and kitchen staff can access everything
        if request.user.is_staff or request.user.groups.filter(name='Kitchen Staff').exists():
            return True
        
        # Check if user owns the order
        return obj.subscription.customer.user == request.user

class CanManageInventory(permissions.BasePermission):
    """
    Custom permission to only allow inventory management by authorized users.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name__in=['Kitchen Staff', 'Manager']).exists())
        )

class CanManageUsers(permissions.BasePermission):
    """
    Custom permission to only allow user management by admins and managers.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name='Manager').exists())
        )

class CanViewReports(permissions.BasePermission):
    """
    Custom permission to only allow report viewing by authorized users.
    """
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            (request.user.is_staff or 
             request.user.groups.filter(name__in=['Manager', 'Kitchen Staff']).exists())
        )

class IsActiveSubscription(permissions.BasePermission):
    """
    Custom permission to only allow access to active subscriptions.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin can access everything
        if request.user.is_staff:
            return True
        
        # Check if subscription is active
        return obj.status == 'active'

class CanModifySubscription(permissions.BasePermission):
    """
    Custom permission to only allow subscription modification by owners or admins.
    """
    
    def has_object_permission(self, request, view, obj):
        # Admin can modify everything
        if request.user.is_staff:
            return True
        
        # Owner can modify their own subscriptions
        if obj.customer.user == request.user:
            # Check if subscription is in a modifiable state
            return obj.status in ['active', 'paused']
        
        return False 