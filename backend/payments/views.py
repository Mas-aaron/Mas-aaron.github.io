import uuid
from django.conf import settings
from django.shortcuts import render, redirect
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .pesapal_service import PesapalService
from .models import Payment

pesapal = PesapalService()

@api_view(['GET'])
def payment_options(request):
    """Return available payment options"""
    return JsonResponse({
        'payment_methods': [
            {
                'id': 'pesapal',
                'name': 'Pesapal',
                'description': 'Pay with M-Pesa, Card, or Bank',
                'enabled': True
            }
        ]
    })

@api_view(['POST'])
@csrf_exempt
def initiate_payment(request):
    """Initialize a Pesapal payment"""
    amount = request.data.get('amount')
    order_id = request.data.get('order_id')
    
    payload = {
        "id": order_id,
        "currency": "KES",
        "amount": float(amount),
        "description": "Payment for order #" + order_id,
        "callback_url": settings.PESAPAL_CALLBACK_URL,
        "notification_id": settings.PESAPAL_IPN_URL,
        "billing_address": {
            "email_address": request.data.get('email'),
            "phone_number": request.data.get('phone'),
            "first_name": request.data.get('first_name', ''),
            "last_name": request.data.get('last_name', ''),
        }
    }

    response = pesapal.submit_order_request(payload)
    return JsonResponse(response)

@csrf_exempt
def payment_callback(request):
    tracking_id = request.GET.get('OrderTrackingId')
    merchant_reference = request.GET.get('OrderMerchantReference')
    
    payment = Payment.objects.get(order_tracking_id=tracking_id)
    status = pesapal.get_transaction_status(tracking_id, merchant_reference)
    
    if status:
        payment.status = status.get('payment_status', 'PENDING')
        payment.save()
    
    return render(request, 'payments/callback.html', {'payment': payment})

@csrf_exempt
def payment_ipn(request):
    tracking_id = request.GET.get('OrderTrackingId')
    merchant_reference = request.GET.get('OrderMerchantReference')
    
    status = pesapal.get_transaction_status(tracking_id, merchant_reference)
    if status:
        payment = Payment.objects.get(order_tracking_id=tracking_id)
        payment.status = status.get('payment_status', 'PENDING')
        payment.save()
    
    return JsonResponse({'status': 'success'})

@api_view(['GET'])
def test_payment_integration(request):
    """Test if payment integration is working"""
    return Response({
        'status': 'success',
        'message': 'Payment integration is working',
        'pesapal_enabled': True,
        'endpoints': {
            'initiate': '/api/payments/initiate/',
            'callback': '/api/payments/callback/',
            'ipn': '/api/payments/ipn/',
            'options': '/api/payments/options/'
        }
    })
