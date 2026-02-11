from django.shortcuts import render
from django.http import JsonResponse

def index(request):
    return render(request, 'driver/index.html')

def api_index(request):
    return JsonResponse({
        'message': 'driver API endpoint'
    })
