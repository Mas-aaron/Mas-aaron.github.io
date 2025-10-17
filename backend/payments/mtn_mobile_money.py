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
        self.target_environment = "sandbox"  # or "production"
        
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
                'Content-Type': 'application/json'
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
            
            logger.info(f"🏦 Sending MTN MoMo request: {payload}")
            
            response = requests.post(url, json=payload, headers=headers)
            
            if response.status_code == 202:  # Accepted
                logger.info("✅ MTN payment request sent successfully")
                return {
                    'success': True,
                    'reference_id': reference_id,
                    'message': f'Payment request sent to {phone_number}. Please check your phone and enter your PIN.'
                }
            else:
                logger.error(f"MTN payment request failed: {response.status_code} - {response.text}")
                return {
                    'success': False,
                    'error': f'MTN API error: {response.status_code}'
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
