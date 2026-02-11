from rest_framework import viewsets, permissions, status, decorators
from rest_framework.response import Response
from django.utils import timezone
from apps.driver.models import DeliveryAssignment, DeliveryStatus
from apps.driver.serializers.driver_serializers import DeliveryAssignmentSerializer

class DriverDeliveryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for drivers to see their deliveries and update status.
    """
    serializer_class = DeliveryAssignmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Filter for the current user's driver profile and today's deliveries
        user = self.request.user
        if not hasattr(user, 'deliverydriver') and not hasattr(user, 'driver_profile'): 
             # Assuming a link exists, but based on models provided earlier:
             # DeliveryDriver model didn't seem to have a OneToOne to User in the snippet provided in previous turns?
             # Checking `apps/driver/models.py` again... `DeliveryAssignment` links to `DeliveryDriver`.
             # If `DeliveryDriver` doesn't link to `User`, we might have a problem identifying the driver from `request.user`.
             # Retrospective: The `DeliveryDriver` model has `phone` and `email` but no `user` OneToOneField in the content I saw earlier.
             # However, typically in this architecture, there should be a link. 
             # I will assume for now there might be a linkage I missed or I need to handle it.
             # Actually, looking at `migrations/0001_initial.py` which had `Driver` linked to `User`, 
             # but `DeliveryDriver` in `models.py` (which I read in turn 2) did NOT have a `user` field.
             # This is a potential issue.
             # For the sake of this task, I will assume the driver is authenticated via the same User system 
             # and we might need to find the driver by email or phone, OR there is a missing link.
             # Let's check if I can filter by `driver__email=user.email` or similar if no direct link.
             # But best practice is `user` field. 
             # FORCE FIX: I'll assume we filter based on some property or just return all for checking if I can't find the link.
             # Wait, `UserProfile` or similar might help.
             # Let's write the code to look for a `driver` attribute or filter by email.
             
             # Re-reading `DeliveryDriver` in `apps/driver/models.py` from Turn 2:
             # class DeliveryDriver(models.Model):
             #     name = models.CharField(max_length=100)
             #     phone = models.CharField(max_length=20, unique=True)
             #     email = models.EmailField(blank=True, null=True)
             # ...
             
             # It does NOT have a user field. This is a design gap for a "logged in driver".
             # However, `apps/driver/admin.py` (old one) referenced `user`.
             # The user asked: "Generate... for a Driver to... List all deliveries assigned to them".
             # I will implement it assuming there is a way to link. 
             # I will filter by `driver__email=self.request.user.email` as a fallback if `driver` attr is missing.
             pass
        
        queryset = DeliveryAssignment.objects.filter(
            delivery_status__date=timezone.now().date()
        ).select_related('delivery_status', 'delivery_status__subscription__customer')

        # Try to filter by logged in driver
        if hasattr(user, 'email'):
             return queryset.filter(driver__email=user.email)
        
        return queryset.none()

    @decorators.action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        assignment = self.get_object()
        delivery_status = assignment.delivery_status
        
        new_status = request.data.get('status')
        if new_status not in ['out_for_delivery', 'delivered']:
            return Response(
                {'error': 'Invalid status. Allowed: out_for_delivery, delivered'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Logic for status transition
        if new_status == 'delivered':
            delivery_status.mark_as_delivered()
        else:
            delivery_status.status = new_status
            delivery_status.save(update_fields=['status'])
            
        return Response({'status': 'success', 'new_status': delivery_status.status})

    @decorators.action(detail=True, methods=['post'])
    def add_note(self, request, pk=None):
        assignment = self.get_object()
        delivery_status = assignment.delivery_status
        
        note = request.data.get('note')
        if not note:
             return Response({'error': 'Note is required'}, status=status.HTTP_400_BAD_REQUEST)
             
        # Append note
        if delivery_status.driver_notes:
            delivery_status.driver_notes += f"\n{note}"
        else:
            delivery_status.driver_notes = note
        
        delivery_status.save(update_fields=['driver_notes'])
        return Response({'status': 'success', 'driver_notes': delivery_status.driver_notes})
