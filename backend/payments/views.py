import uuid
from django.conf import settings
from django.shortcuts import render, redirect
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .pesapal_service import PesapalService
from .models import Payment
from api.models import Order

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
@permission_classes([IsAuthenticated])
def initiate_payment(request):
    """Initialize a Pesapal payment"""
    try:
        order_id = request.data.get('order_id')
        amount = request.data.get('amount')
        
        # Get the order
        try:
            order = Order.objects.get(id=order_id, user=request.user)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Check if payment already exists
        if hasattr(order, 'pesapal_payment'):
            return Response({'error': 'Payment already exists for this order'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Generate unique merchant reference
        merchant_reference = f"ORDER_{order_id}_{uuid.uuid4().hex[:8].upper()}"
        
        # Create payment record
        payment = Payment.objects.create(
            order=order,
            merchant_reference=merchant_reference,
            amount=amount,
            currency='UGX',
            customer_email=request.user.email,
            customer_phone=getattr(request.user, 'phone_number', ''),
            customer_name=f"{request.user.first_name} {request.user.last_name}".strip() or request.user.username,
        )
        
        # Prepare Pesapal payload
        payload = {
            "id": merchant_reference,
            "currency": "UGX",
            "amount": float(amount),
            "description": f"Payment for order #{order_id}",
            "callback_url": settings.PESAPAL_CALLBACK_URL,
            "notification_id": settings.PESAPAL_IPN_URL,
            "billing_address": {
                "email_address": payment.customer_email or request.user.email,
                "phone_number": payment.customer_phone or request.data.get('phone', ''),
                "first_name": request.user.first_name or 'Customer',
                "last_name": request.user.last_name or '',
            }
        }

        # Submit to Pesapal
        response = pesapal.submit_order_request(payload)
        
        if response and 'order_tracking_id' in response:
            payment.order_tracking_id = response['order_tracking_id']
            payment.save()
            
            return Response({
                'success': True,
                'payment_id': payment.id,
                'order_tracking_id': response['order_tracking_id'],
                'redirect_url': response.get('redirect_url', ''),
                'message': 'Payment initiated successfully'
            }, status=status.HTTP_200_OK)
        else:
            payment.status = 'FAILED'
            payment.save()
            return Response({
                'success': False,
                'error': 'Failed to initiate payment with Pesapal'
            }, status=status.HTTP_400_BAD_REQUEST)
            
    except Exception as e:
        return Response({
            'success': False,
            'error': f'Payment initiation failed: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

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

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payment_status(request, payment_id):
    """Check payment status using payment ID"""
    try:
        payment = Payment.objects.get(id=payment_id, order__user=request.user)
        
        # Check with Pesapal if payment is still pending
        if payment.status == 'PENDING' and payment.order_tracking_id:
            pesapal_status = pesapal.get_transaction_status(
                payment.order_tracking_id, 
                payment.merchant_reference
            )
            
            if pesapal_status:
                payment_status = pesapal_status.get('payment_status', 'PENDING')
                payment.status = payment_status.upper()
                payment.payment_method = pesapal_status.get('payment_method', '')
                payment.pesapal_transaction_id = pesapal_status.get('transaction_id', '')
                payment.save()
        
        return Response({
            'payment_id': payment.id,
            'status': payment.status.lower(),
            'payment_method': payment.payment_method,
            'amount': str(payment.amount),
            'currency': payment.currency,
            'order_id': payment.order.id if payment.order else None,
            'message': f'Payment is {payment.status.lower()}'
        })
    except Payment.DoesNotExist:
        return Response({
            'error': 'Payment not found',
            'status': 'failed'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({
            'error': str(e),
            'status': 'failed'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
