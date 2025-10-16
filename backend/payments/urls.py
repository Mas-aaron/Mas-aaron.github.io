from django.urls import path
from . import views

app_name = 'payments'

urlpatterns = [
    path('initiate/', views.initiate_payment, name='initiate'),
    path('callback/', views.payment_callback, name='callback'),
    path('ipn/', views.payment_ipn, name='ipn'),
    path('options/', views.payment_options, name='options'),
    path('status/<int:payment_id>/', views.payment_status, name='status'),
    path('test/', views.test_payment_integration, name='test'),
]

