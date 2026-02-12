from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from apps.users.models import Tenant

class TenantDiscoveryView(APIView):
    def get(self, request):
        slug = request.query_params.get('slug')
        if not slug:
            return Response({'error': 'Slug is required'}, status=status.HTTP_400_BAD_REQUEST)

        # Assuming 'subdomain' is the field used for the slug/kitchen code
        tenant = Tenant.objects.filter(subdomain__iexact=slug).first()

        if tenant:
            if not tenant.is_active:
                return Response({'error': 'Kitchen is inactive'}, status=status.HTTP_403_FORBIDDEN)
            
            return Response({
                'name': tenant.name,
                'api_endpoint': 'http://127.0.0.1:8000/api/v1/', # Default to local for now as per instructions/context
                'tenant_id': tenant.subdomain
            }, status=status.HTTP_200_OK)
        else:
            return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)
