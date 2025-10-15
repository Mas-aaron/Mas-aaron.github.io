import uuid
from django.conf import settings
from django.shortcuts import render, redirect
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from .pesapal_service import PesapalService
from .models import Payment

pesapal = PesapalService()

def initiate_payment(request):
    # Create payment payload
    order_id = str(uuid.uuid4())
    amount = request.POST.get('amount')
    
    payload = {
        "id": order_id,
        "currency": "KES",
        "amount": float(amount),
        "description": "Payment for order",
        "callback_url": settings.PESAPAL_CALLBACK_URL,
        "notification_id": settings.PESAPAL_IPN_URL,
        "billing_address": {
            "email_address": request.POST.get('email'),
            "phone_number": request.POST.get('phone'),
            "first_name": request.POST.get('first_name'),
            "last_name": request.POST.get('last_name'),
        }
    }

    # Submit order to Pesapal
    response = pesapal.submit_order_request(payload)
    
    if response.get('redirect_url'):
        Payment.objects.create(
            order_tracking_id=response.get('order_tracking_id'),
            merchant_reference=order_id,
            amount=amount,
        )
        return redirect(response['redirect_url'])
    
    return JsonResponse({'error': 'Payment initialization failed'}, status=400)

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
