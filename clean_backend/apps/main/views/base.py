from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt


def home(request):
    return render(request, 'index.html')


@csrf_exempt
def health_check(request):
    return JsonResponse({
        'status': 'healthy',
        'message': 'Fun Adventure Kitchen Backend is running!'
    })


def handler404(request, exception):
    return JsonResponse({
        'error': 'Page not found',
        'status': 404
    }, status=404)


def handler500(request):
    return JsonResponse({
        'error': 'Internal server error',
        'status': 500
    }, status=500)
