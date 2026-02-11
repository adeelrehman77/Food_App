from django.shortcuts import render
from django.http import JsonResponse

def index(request):
    return render(request, 'delivery/index.html')

def api_index(request):
    return JsonResponse({
        'message': 'delivery API endpoint'
    })
