from django.urls import path
from . import views

app_name = 'payments'

urlpatterns = [
    path('initiate/', views.initiate_payment, name='initiate'),
    path('callback/', views.payment_callback, name='callback'),
    path('ipn/', views.payment_ipn, name='ipn'),
]
