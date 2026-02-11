from django.shortcuts import render
from django.http import JsonResponse

def index(request):
    return render(request, 'inventory/index.html')

def api_index(request):
    return JsonResponse({
        'message': 'inventory API endpoint'
    })
