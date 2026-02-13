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
        if hasattr(user, 'driver_profile'):
            return queryset.filter(driver=user.driver_profile)

        # Fallback for old records without user link (temporary)
        if hasattr(user, 'email') and user.email:
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
