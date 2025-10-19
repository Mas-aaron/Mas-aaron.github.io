#!/usr/bin/env python3
"""
MTN Mobile Money API Debug Test Script
This script tests the MTN API configuration and helps debug issues
"""
import os
import sys
import django

# Setup Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from payments.mtn_mobile_money import MTNMobileMoneyAPI
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_mtn_configuration():
    """Test MTN API configuration and basic functionality"""
    print("🚀 MTN Mobile Money API Debug Test")
    print("=" * 50)
    
    try:
        # Test 1: Initialize API
        print("\n1️⃣ Testing MTN API Initialization...")
        mtn_api = MTNMobileMoneyAPI()
        print("✅ MTN API initialized successfully")
        
        # Test 2: Test token generation
        print("\n2️⃣ Testing Access Token Generation...")
        token = mtn_api.get_access_token()
        if token:
            print(f"✅ Access token obtained: {token[:20]}...")
        else:
            print("❌ Failed to obtain access token")
            return False
        
        # Test 3: Test phone number validation
        print("\n3️⃣ Testing Phone Number Validation...")
        test_phones = [
            "256783876390",
            "0783876390", 
            "+256783876390",
            "256777123456"
        ]
        
        for phone in test_phones:
            formatted = mtn_api._validate_and_format_phone_number(phone)
            print(f"   {phone} → {formatted}")
        
        # Test 4: Test amount validation
        print("\n4️⃣ Testing Amount Validation...")
        test_amounts = [505.0, "505", 100, 50, 1000000]
        
        for amount in test_amounts:
            formatted = mtn_api._validate_and_format_amount(amount)
            print(f"   {amount} → {formatted}")
        
        print("\n✅ All basic tests passed!")
        return True
        
    except Exception as e:
        print(f"\n❌ Test failed: {str(e)}")
        import traceback
        print(f"📄 Traceback: {traceback.format_exc()}")
        return False

def test_payment_request():
    """Test a sample payment request (without actually processing)"""
    print("\n🔄 Testing Sample Payment Request...")
    print("=" * 50)
    
    try:
        mtn_api = MTNMobileMoneyAPI()
        
        # Test payment parameters
        phone = "256783876390"
        amount = 505
        external_id = "TEST001"
        message = "Test Payment"
        
        print(f"📱 Phone: {phone}")
        print(f"💰 Amount: {amount}")
        print(f"🆔 External ID: {external_id}")
        print(f"💬 Message: {message}")
        
        # This will show us exactly what gets sent to MTN
        result = mtn_api.request_to_pay(
            phone_number=phone,
            amount=amount,
            external_id=external_id,
            payer_message=message
        )
        
        print(f"\n📋 Result: {result}")
        
        if result['success']:
            print("✅ Payment request successful!")
        else:
            print(f"❌ Payment request failed: {result.get('error', 'Unknown error')}")
        
        return result
        
    except Exception as e:
        print(f"\n❌ Payment test failed: {str(e)}")
        import traceback
        print(f"📄 Traceback: {traceback.format_exc()}")
        return None

if __name__ == "__main__":
    print("🧪 MTN Mobile Money Debug Test Suite")
    print("This script will help identify issues with the MTN API integration")
    print()
    
    # Run configuration tests
    config_ok = test_mtn_configuration()
    
    if config_ok:
        # Run payment test
        test_payment_request()
    else:
        print("\n⚠️ Configuration tests failed. Fix configuration before testing payments.")
    
    print("\n🏁 Debug test completed!")
