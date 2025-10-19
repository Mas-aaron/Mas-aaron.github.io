"""
Direct MTN Mobile Money Uganda Integration
This bypasses PesaPal and integrates directly with MTN MoMo API
"""
import requests
import uuid
import base64
import logging
from django.conf import settings

# Ensure all required modules are available
try:
    import json
    logger = logging.getLogger(__name__)
    logger.info("✅ All MTN API dependencies loaded successfully")
except ImportError as e:
    logger = logging.getLogger(__name__)
    logger.error(f"❌ Missing dependency: {e}")

logger = logging.getLogger(__name__)

class MTNMobileMoneyAPI:
    def __init__(self):
        # MTN Mobile Money Sandbox credentials
        self.base_url = "https://sandbox.momodeveloper.mtn.com"
        self.subscription_key = settings.MTN_MOMO_CONFIG.get('SUBSCRIPTION_KEY', '')
        self.user_id = settings.MTN_MOMO_CONFIG.get('USER_ID', '')
        self.api_key = settings.MTN_MOMO_CONFIG.get('API_KEY', '')
        self.target_environment = "sandbox"
        
        logger.info(f"🔑 MTN Config - Key: {self.subscription_key[:8]}... User: {self.user_id[:8]}...")
        
    def create_api_user(self):
        """Create API user if it doesn't exist"""
        try:
            url = f"{self.base_url}/v1_0/apiuser"
            
            headers = {
                'X-Reference-Id': self.user_id,
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'Content-Type': 'application/json'
            }
            
            payload = {
                "providerCallbackHost": "food-delivery-backend-2mcb.onrender.com"
            }
            
            response = requests.post(url, json=payload, headers=headers, timeout=10)
            logger.info(f"API User creation response: {response.status_code} - {response.text}")
            
            if response.status_code in [201, 409]:  # Created or Conflict (already exists)
                return True
            else:
                logger.error(f"Failed to create API user: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"API user creation error: {str(e)}")
            return False
    
    def create_api_key(self):
        """Create API key for the user"""
        try:
            url = f"{self.base_url}/v1_0/apiuser/{self.user_id}/apikey"
            
            headers = {
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            response = requests.post(url, headers=headers, timeout=10)
            logger.info(f"API Key creation response: {response.status_code} - {response.text}")
            
            if response.status_code == 201:
                data = response.json()
                return data.get('apiKey')
            else:
                logger.error(f"Failed to create API key: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"API key creation error: {str(e)}")
            return None
        
    def get_access_token(self):
        """Get OAuth access token from MTN"""
        try:
            url = f"{self.base_url}/collection/token/"
            logger.info(f"🔑 Step 2.1: Requesting token from: {url}")
            
            # Create basic auth header
            credentials = f"{self.user_id}:{self.api_key}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                'Authorization': f'Basic {encoded_credentials}',
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            logger.info(f"🔑 Token request details:")
            logger.info(f"   User ID: {self.user_id}")
            logger.info(f"   API Key: {self.api_key[:8]}...")
            logger.info(f"   Subscription Key: {self.subscription_key[:8]}...")
            
            response = requests.post(url, headers=headers, timeout=10)
            
            logger.info(f"🔑 Token response:")
            logger.info(f"   Status: {response.status_code}")
            logger.info(f"   Headers: {dict(response.headers)}")
            logger.info(f"   Body: {response.text}")
            
            if response.status_code == 200:
                data = response.json()
                token = data.get('access_token')
                expires_in = data.get('expires_in')
                logger.info(f"✅ Token obtained: {token[:20] if token else 'None'}... (expires in {expires_in}s)")
                return token
            else:
                logger.error(f"❌ Token request failed with status: {response.status_code}")
                if response.status_code == 401:
                    logger.error("🔐 401 Unauthorized - Check your API User ID and API Key")
                elif response.status_code == 403:
                    logger.error("🔐 403 Forbidden - Check your Subscription Key")
                return None
                
        except Exception as e:
            logger.error(f"💥 Token error: {str(e)}")
            import traceback
            logger.error(f"📄 Token traceback: {traceback.format_exc()}")
            return None
    
    def request_to_pay(self, phone_number, amount, external_id, payer_message="Food Delivery Payment"):
        """
        Request payment from MTN Mobile Money user
        This triggers the USSD prompt on user's phone
        """
        try:
            logger.info(f"🔧 Step 1: Creating API user...")
            
            # Test basic connectivity first
            try:
                test_response = requests.get(f"{self.base_url}/", timeout=5)
                logger.info(f"🌐 MTN API connectivity test: {test_response.status_code}")
            except Exception as conn_error:
                logger.warning(f"⚠️ MTN API connectivity issue: {conn_error}")
            
            if not self.create_api_user():
                logger.warning("⚠️ Could not create/verify API user, continuing anyway...")
            
            logger.info(f"🔧 Step 2: Getting access token...")
            token = self.get_access_token()
            if not token:
                raise Exception("Failed to get MTN access token")
            
            logger.info(f"✅ Token obtained, proceeding with payment request...")
            
            url = f"{self.base_url}/collection/v1_0/requesttopay"
            
            # Generate unique reference ID
            reference_id = str(uuid.uuid4())
            
            # Format phone number (your existing logic is good)
            formatted_phone = phone_number
            
            if phone_number.startswith('+256'):
                formatted_phone = phone_number[1:]
            elif phone_number.startswith('0'):
                formatted_phone = '256' + phone_number[1:]
            elif phone_number.startswith('256'):
                formatted_phone = phone_number
            else:
                formatted_phone = '256' + phone_number
            
            logger.info(f"📱 Phone formatting: {phone_number} -> {formatted_phone}")
            
            # **CRITICAL FIX: Amount must be in string format without decimals for UGX**
            # MTN expects amount as string without decimal places for UGX
            amount_str = str(int(float(amount)))  # Convert "25.0" to "25"
            
            logger.info(f"💰 Amount conversion: {amount} -> {amount_str}")
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Reference-Id': reference_id,
                'X-Target-Environment': self.target_environment,
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'Content-Type': 'application/json',
            }
            
            payload = {
                "amount": amount_str,  # Use converted amount
                "currency": "UGX",
                "externalId": external_id,
                "payer": {
                    "partyIdType": "MSISDN",
                    "partyId": formatted_phone
                },
                "payerMessage": payer_message[:20],  # MTN limits to 20 chars
                "payeeNote": f"Order {external_id}"[:20]  # MTN limits to 20 chars
            }
            
            logger.info("Sending MTN Request:")
            logger.info(f"URL: {url}")
            logger.info(f"Headers: {dict((k, v[:100] + '...' if k == 'Authorization' else v) for k, v in headers.items())}")
            logger.info(f"Payload: {payload}")
            
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"Response Status: {response.status_code}")
            logger.info(f"Response Headers: {dict(response.headers)}")
            logger.info(f"Response Body: {response.text}")
            logger.info(f"📄 Response Headers: {dict(response.headers)}")
            logger.info(f"📝 Response Body: {response.text}")
            
            if response.status_code == 202:
                logger.info("✅ MTN payment request accepted - user should receive USSD prompt")
                return {
                    'success': True,
                    'reference_id': reference_id,
                    'message': f'Payment request sent to {phone_number}. Please check your phone and enter your PIN.'
                }
            else:
                logger.error(f"❌ MTN API Error: {response.status_code}")
                
                # Enhanced error parsing
                error_details = f"Status: {response.status_code}"
                try:
                    error_json = response.json()
                    error_details += f" - JSON: {error_json}"
                except:
                    error_details += f" - Text: {response.text}"
                
                return {
                    'success': False,
                    'error': f'MTN API Error: {error_details}',
                    'status_code': response.status_code,
                    'raw_response': response.text
                }
                
        except requests.exceptions.RequestException as e:
            logger.error(f"🌐 Network error: {str(e)}")
            return {
                'success': False,
                'error': f'Network error: {str(e)}'
            }
        except Exception as e:
            logger.error(f"💥 Unexpected error: {str(e)}")
            import traceback
            logger.error(f"📄 Stack trace: {traceback.format_exc()}")
            return {
                'success': False,
                'error': f'Unexpected error: {str(e)}'
            }
    
    def check_payment_status(self, reference_id):
        """Check the status of a payment request"""
        try:
            token = self.get_access_token()
            if not token:
                return None
            
            url = f"{self.base_url}/collection/v1_0/requesttopay/{reference_id}"
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Target-Environment': self.target_environment,
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            response = requests.get(url, headers=headers)
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"MTN status check failed: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"MTN status check error: {str(e)}")
            return None
