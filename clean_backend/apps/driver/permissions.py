from rest_framework import permissions

class IsLogisticsAdmin(permissions.BasePermission):
    """
    Custom permission to only allow access to non-driver staff.
    Drivers are staff (to access the app), but should not access admin/management views.
    """

    def has_permission(self, request, view):
        # Must be configured user
        if not request.user or not request.user.is_authenticated:
            return False
            
        # If user has a driver profile, DENY access to management features
        if hasattr(request.user, 'driver_profile'):
            return False
            
        # Must be staff to access these views at all
        return request.user.is_staff
