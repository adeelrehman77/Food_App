from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from apps.users.models import Tenant


class TenantDiscoveryView(APIView):
    """Public endpoint to discover a tenant by slug."""
    permission_classes = [permissions.AllowAny]

    def _build_api_endpoint(self, request):
        """Build the API endpoint URL dynamically from the incoming request."""
        scheme = 'https' if request.is_secure() else 'http'
        host = request.get_host()
        return f'{scheme}://{host}/api/v1/'

    def get(self, request):
        slug = request.query_params.get('slug')
        if not slug:
            return Response(
                {'error': 'Slug query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        tenant = Tenant.objects.filter(subdomain__iexact=slug).first()

        if not tenant:
            return Response(
                {'error': 'Kitchen not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not tenant.is_active:
            return Response(
                {'error': 'This kitchen is currently inactive'},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response({
            'name': tenant.name,
            'api_endpoint': self._build_api_endpoint(request),
            'tenant_id': tenant.subdomain,
        }, status=status.HTTP_200_OK)
