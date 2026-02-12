"""
Plan-based permission classes.

These check the tenant's ServicePlan limits before allowing create operations.
Attach to any ViewSet whose model count should be gated by the plan.

Usage:
    class MenuItemViewSet(viewsets.ModelViewSet):
        permission_classes = [IsAuthenticated, PlanLimitMenuItems]
"""
from rest_framework import permissions


class _BasePlanLimitPermission(permissions.BasePermission):
    """
    Base class for plan-limit checks. Subclasses set:
      - ``limit_name``: the ServicePlan field suffix (e.g. 'menu_items')
      - ``model_class``: the Django model to count
      - ``feature_name``: (optional) a feature flag that must be True
    """
    limit_name = None
    model_class = None
    feature_name = None
    message = "You have reached the limit for your current plan."

    def has_permission(self, request, view):
        # Only gate create actions
        if view.action not in ('create',):
            return True

        plan = getattr(request, 'tenant_plan', None)
        if plan is None:
            # No plan assigned — allow (or deny, depending on policy).
            # Default: allow so development/testing isn't blocked.
            return True

        # Check feature flag if required
        if self.feature_name and not plan.has_feature(self.feature_name):
            self.message = (
                f"Your plan does not include the '{self.feature_name}' feature. "
                "Please upgrade."
            )
            return False

        # Check count limit
        if self.limit_name and self.model_class:
            current_count = self.model_class.objects.count()
            if not plan.check_limit(self.limit_name, current_count):
                max_val = getattr(plan, f'max_{self.limit_name}', '?')
                self.message = (
                    f"Your plan allows a maximum of {max_val} {self.limit_name.replace('_', ' ')}. "
                    "Please upgrade."
                )
                return False

        return True


class PlanLimitMenuItems(_BasePlanLimitPermission):
    limit_name = 'menu_items'

    @property
    def model_class(self):
        from apps.main.models import MenuItem
        return MenuItem


class PlanLimitStaffUsers(_BasePlanLimitPermission):
    limit_name = 'staff_users'

    @property
    def model_class(self):
        from django.contrib.auth.models import User
        return User


class PlanLimitCustomers(_BasePlanLimitPermission):
    limit_name = 'customers'

    @property
    def model_class(self):
        from apps.main.models import CustomerProfile
        return CustomerProfile


class PlanFeatureInventory(_BasePlanLimitPermission):
    feature_name = 'inventory_management'


class PlanFeatureDeliveryTracking(_BasePlanLimitPermission):
    feature_name = 'delivery_tracking'


class PlanFeatureAnalytics(_BasePlanLimitPermission):
    feature_name = 'analytics'


class PlanFeatureWhatsApp(_BasePlanLimitPermission):
    feature_name = 'whatsapp_notifications'
