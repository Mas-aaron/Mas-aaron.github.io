"""
One-time MTN API setup endpoint for Render free tier
Visit this endpoint once to generate credentials, then disable it
"""
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings
import requests
import uuid
import base64


@require_http_methods(["GET"])
@csrf_exempt
def mtn_setup_create_user(request):
    """
    Create MTN API user
    Visit: /api/mtn-setup/create-user/
    """
    try:
        mtn_config = settings.MTN_MOMO_CONFIG
        subscription_key = mtn_config.get('SUBSCRIPTION_KEY', '')
        callback_host = mtn_config.get('CALLBACK_HOST', 'food-delivery-backend-2mcb.onrender.com')
        base_url = "https://sandbox.momodeveloper.mtn.com"
        
        if not subscription_key or subscription_key == 'your_subscription_key_here':
            return JsonResponse({
                'error': 'Subscription key not configured',
                'instruction': 'Set MTN_MOMO_SUBSCRIPTION_KEY environment variable'
            }, status=400)
        
        # Generate unique reference ID
        reference_id = str(uuid.uuid4())
        
        url = f"{base_url}/v1_0/apiuser"
        headers = {
            'X-Reference-Id': reference_id,
            'Ocp-Apim-Subscription-Key': subscription_key,
            'Content-Type': 'application/json'
        }
        payload = {
            "providerCallbackHost": callback_host
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 201:
            return JsonResponse({
                'success': True,
                'user_id': reference_id,
                'message': 'API User created successfully',
                'next_step': 'Add this to Render environment variables',
                'env_var_name': 'MTN_MOMO_USER_ID',
                'env_var_value': reference_id,
                'next_endpoint': '/api/mtn-setup/get-api-key/'
            })
        elif response.status_code == 409:
            return JsonResponse({
                'success': True,
                'message': 'API User already exists',
                'note': 'You may already have a User ID configured',
                'next_endpoint': '/api/mtn-setup/get-api-key/'
            })
        else:
            return JsonResponse({
                'error': f'Failed to create API user: {response.status_code}',
                'response': response.text
            }, status=500)
            
    except Exception as e:
        return JsonResponse({
            'error': str(e),
            'type': type(e).__name__
        }, status=500)


@require_http_methods(["GET"])
@csrf_exempt
def mtn_setup_get_api_key(request):
    """
    Generate API Key for existing user
    Visit: /api/mtn-setup/get-api-key/
    """
    try:
        mtn_config = settings.MTN_MOMO_CONFIG
        subscription_key = mtn_config.get('SUBSCRIPTION_KEY', '')
        user_id = mtn_config.get('USER_ID', '')
        base_url = "https://sandbox.momodeveloper.mtn.com"
        
        if not user_id or user_id == 'your_user_id_here':
            return JsonResponse({
                'error': 'User ID not configured',
                'instruction': 'First visit /api/mtn-setup/create-user/ or set MTN_MOMO_USER_ID'
            }, status=400)
        
        url = f"{base_url}/v1_0/apiuser/{user_id}/apikey"
        headers = {
            'Ocp-Apim-Subscription-Key': subscription_key
        }
        
        response = requests.post(url, headers=headers, timeout=30)
        
        if response.status_code == 201:
            data = response.json()
            api_key = data.get('apiKey')
            return JsonResponse({
                'success': True,
                'api_key': api_key,
                'message': 'API Key generated successfully',
                'next_step': 'Add this to Render environment variables',
                'env_var_name': 'MTN_MOMO_API_KEY',
                'env_var_value': api_key,
                'next_endpoint': '/api/mtn-setup/test-credentials/'
            })
        else:
            return JsonResponse({
                'error': f'Failed to generate API key: {response.status_code}',
                'response': response.text
            }, status=500)
            
    except Exception as e:
        return JsonResponse({
            'error': str(e),
            'type': type(e).__name__
        }, status=500)


@require_http_methods(["GET"])
@csrf_exempt
def mtn_setup_test_credentials(request):
    """
    Test MTN credentials
    Visit: /api/mtn-setup/test-credentials/
    """
    try:
        mtn_config = settings.MTN_MOMO_CONFIG
        subscription_key = mtn_config.get('SUBSCRIPTION_KEY', '')
        user_id = mtn_config.get('USER_ID', '')
        api_key = mtn_config.get('API_KEY', '')
        base_url = "https://sandbox.momodeveloper.mtn.com"
        
        if not all([user_id, api_key]) or user_id == 'your_user_id_here' or api_key == 'your_api_key_here':
            return JsonResponse({
                'error': 'Credentials not configured',
                'subscription_key_ok': bool(subscription_key and subscription_key != 'your_subscription_key_here'),
                'user_id_ok': bool(user_id and user_id != 'your_user_id_here'),
                'api_key_ok': bool(api_key and api_key != 'your_api_key_here'),
            }, status=400)
        
        url = f"{base_url}/collection/token/"
        credentials = f"{user_id}:{api_key}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        
        headers = {
            'Authorization': f'Basic {encoded_credentials}',
            'Ocp-Apim-Subscription-Key': subscription_key
        }
        
        response = requests.post(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            token = data.get('access_token')
            expires_in = data.get('expires_in', 0)
            return JsonResponse({
                'success': True,
                'message': 'MTN API integration is ready!',
                'access_token': token[:20] + '...' if token else None,
                'expires_in': expires_in,
                'status': 'All credentials are valid',
                'next_step': 'MTN payments are now working'
            })
        else:
            return JsonResponse({
                'error': f'Credential test failed: {response.status_code}',
                'response': response.text,
                'possible_issues': [
                    'Invalid User ID',
                    'Invalid API Key', 
                    'Invalid Subscription Key',
                    'API User not properly created'
                ]
            }, status=500)
            
    except Exception as e:
        return JsonResponse({
            'error': str(e),
            'type': type(e).__name__
        }, status=500)
