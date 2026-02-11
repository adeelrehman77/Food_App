from django.shortcuts import render
from django.http import JsonResponse


def dashboard(request):
    return render(request, 'kitchen/dashboard.html')


def order_list(request):
    return JsonResponse({
        'orders': [],
        'message': 'Kitchen orders endpoint'
    }) 