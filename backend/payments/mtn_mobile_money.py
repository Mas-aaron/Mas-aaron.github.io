"""
Direct MTN Mobile Money Uganda Integration
This bypasses PesaPal and integrates directly with MTN MoMo API
"""
import requests
import uuid
import base64
import logging
from django.conf import settings

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
            
            # Create basic auth header
            credentials = f"{self.user_id}:{self.api_key}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                'Authorization': f'Basic {encoded_credentials}',
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'X-Target-Environment': self.target_environment,
                'Content-Type': 'application/json'
            }
            
            response = requests.post(url, headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                return data.get('access_token')
            else:
                logger.error(f"MTN token request failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"MTN token error: {str(e)}")
            return None
    
    def request_to_pay(self, phone_number, amount, external_id, payer_message="Food Delivery Payment"):
        """
        Request payment from MTN Mobile Money user
        This triggers the USSD prompt on user's phone
        """
        try:
            # Ensure API user exists
            if not self.create_api_user():
                logger.warning("Could not create/verify API user, continuing anyway...")
            
            token = self.get_access_token()
            if not token:
                raise Exception("Failed to get MTN access token")
            
            url = f"{self.base_url}/collection/v1_0/requesttopay"
            
            # Generate unique reference ID
            reference_id = str(uuid.uuid4())
            
            # Format phone number (remove +256, add 256)
            if phone_number.startswith('+256'):
                formatted_phone = '256' + phone_number[4:]
            elif phone_number.startswith('0'):
                formatted_phone = '256' + phone_number[1:]
            else:
                formatted_phone = phone_number
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Reference-Id': reference_id,
                'X-Target-Environment': self.target_environment,
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            payload = {
                "amount": str(amount),
                "currency": "UGX",
                "externalId": external_id,
                "payer": {
                    "partyIdType": "MSISDN",
                    "partyId": formatted_phone
                },
                "payerMessage": payer_message,
                "payeeNote": f"Payment for order {external_id}"
            }
            
            logger.info(f"🏦 Sending MTN MoMo request to: {url}")
            logger.info(f"📋 Headers: {headers}")
            logger.info(f"📦 Payload: {payload}")
            
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"📤 MTN API Response: {response.status_code}")
            logger.info(f"📄 MTN Response Body: {response.text}")
            
            if response.status_code == 202:  # Accepted
                logger.info("✅ MTN payment request sent successfully")
                return {
                    'success': True,
                    'reference_id': reference_id,
                    'message': f'Payment request sent to {phone_number}. Please check your phone and enter your PIN.'
                }
            else:
                logger.error(f"❌ MTN payment request failed: {response.status_code}")
                logger.error(f"📄 MTN Error Response: {response.text}")
                
                # Try to parse error details
                try:
                    error_data = response.json()
                    error_msg = error_data.get('message', f'MTN API error: {response.status_code}')
                except:
                    error_msg = f'MTN API error: {response.status_code} - {response.text}'
                
                return {
                    'success': False,
                    'error': error_msg,
                    'status_code': response.status_code,
                    'raw_response': response.text
                }
                
        except Exception as e:
            logger.error(f"MTN payment error: {str(e)}")
            return {
                'success': False,
                'error': str(e)
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
