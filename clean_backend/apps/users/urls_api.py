from django.urls import path
from . import views

app_name = 'users_api'

urlpatterns = [
    path('', views.api_index, name='api_index'),
]
