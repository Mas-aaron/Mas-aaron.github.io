#!/usr/bin/env python3
"""
Direct test of MTN Mobile Money API to debug the 400 error
"""
import requests
import json
import base64
import uuid
from datetime import datetime

# MTN Sandbox Configuration
BASE_URL = "https://sandbox.momodeveloper.mtn.com"
SUBSCRIPTION_KEY = "66957571278f4f28a22b740f272c9161"  # Your actual key
USER_ID = "eede0df2-c6e7-4f8a-a22b-740f272c9161"      # Your actual user ID
API_KEY = "your_api_key_here"                          # Your actual API key

def test_mtn_api():
    print("🧪 Testing MTN Mobile Money API directly...")
    
    # Test 1: Basic connectivity
    try:
        response = requests.get(f"{BASE_URL}/", timeout=10)
        print(f"✅ Basic connectivity: {response.status_code}")
    except Exception as e:
        print(f"❌ Connectivity failed: {e}")
        return
    
    # Test 2: Create API User
    print("\n🔧 Step 1: Creating API User...")
    user_url = f"{BASE_URL}/v1_0/apiuser"
    user_headers = {
        'X-Reference-Id': USER_ID,
        'Ocp-Apim-Subscription-Key': SUBSCRIPTION_KEY,
        'Content-Type': 'application/json'
    }
    user_payload = {
        "providerCallbackHost": "food-delivery-backend-2mcb.onrender.com"
    }
    
    try:
        user_response = requests.post(user_url, json=user_payload, headers=user_headers, timeout=10)
        print(f"📤 API User creation: {user_response.status_code}")
        print(f"📄 Response: {user_response.text}")
        
        if user_response.status_code not in [201, 409]:
            print(f"❌ API User creation failed")
            return
            
    except Exception as e:
        print(f"❌ API User creation error: {e}")
        return
    
    # Test 3: Create API Key
    print("\n🔧 Step 2: Creating API Key...")
    key_url = f"{BASE_URL}/v1_0/apiuser/{USER_ID}/apikey"
    key_headers = {
        'Ocp-Apim-Subscription-Key': SUBSCRIPTION_KEY
    }
    
    try:
        key_response = requests.post(key_url, headers=key_headers, timeout=10)
        print(f"📤 API Key creation: {key_response.status_code}")
        print(f"📄 Response: {key_response.text}")
        
        if key_response.status_code == 201:
            api_key_data = key_response.json()
            actual_api_key = api_key_data.get('apiKey')
            print(f"🔑 Generated API Key: {actual_api_key}")
        else:
            print(f"❌ Using placeholder API key")
            actual_api_key = "placeholder_key"
            
    except Exception as e:
        print(f"❌ API Key creation error: {e}")
        actual_api_key = "placeholder_key"
    
    # Test 4: Get Access Token
    print("\n🔧 Step 3: Getting Access Token...")
    token_url = f"{BASE_URL}/collection/token/"
    credentials = f"{USER_ID}:{actual_api_key}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()
    
    token_headers = {
        'Authorization': f'Basic {encoded_credentials}',
        'Ocp-Apim-Subscription-Key': SUBSCRIPTION_KEY,
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    
    try:
        token_response = requests.post(token_url, headers=token_headers, timeout=10)
        print(f"📤 Token request: {token_response.status_code}")
        print(f"📄 Response: {token_response.text}")
        
        if token_response.status_code == 200:
            token_data = token_response.json()
            access_token = token_data.get('access_token')
            print(f"🔑 Access Token: {access_token[:20]}...")
        else:
            print(f"❌ Token generation failed")
            return
            
    except Exception as e:
        print(f"❌ Token error: {e}")
        return
    
    # Test 5: Request to Pay
    print("\n🔧 Step 4: Testing Request to Pay...")
    pay_url = f"{BASE_URL}/collection/v1_0/requesttopay"
    reference_id = str(uuid.uuid4())
    
    pay_headers = {
        'Authorization': f'Bearer {access_token}',
        'X-Reference-Id': reference_id,
        'X-Target-Environment': 'sandbox',
        'Ocp-Apim-Subscription-Key': SUBSCRIPTION_KEY,
        'Content-Type': 'application/json',
    }
    
    pay_payload = {
        "amount": "15",  # Integer string for UGX
        "currency": "UGX",
        "externalId": "TEST123",
        "payer": {
            "partyIdType": "MSISDN",
            "partyId": "256783876390"
        },
        "payerMessage": "Test Payment",
        "payeeNote": "Test Order"
    }
    
    print(f"📍 URL: {pay_url}")
    print(f"📋 Headers: {pay_headers}")
    print(f"📦 Payload: {pay_payload}")
    
    try:
        pay_response = requests.post(pay_url, json=pay_payload, headers=pay_headers, timeout=30)
        print(f"📤 Payment request: {pay_response.status_code}")
        print(f"📄 Response headers: {dict(pay_response.headers)}")
        print(f"📄 Response body: {pay_response.text}")
        
        if pay_response.status_code == 202:
            print("✅ SUCCESS! Payment request accepted")
        else:
            print(f"❌ Payment request failed: {pay_response.status_code}")
            
    except Exception as e:
        print(f"❌ Payment request error: {e}")

if __name__ == "__main__":
    test_mtn_api()
