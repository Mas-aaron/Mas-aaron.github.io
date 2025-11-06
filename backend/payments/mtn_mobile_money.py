"""
Direct MTN Mobile Money Uganda Integration - CORRECTED VERSION v2.2
Fixed API user provisioning - Nov 6, 2025

IMPORTANT: Before using this integration:
1. Create API user once using: python manage.py setup_mtn_api_user
2. Configure MTN_MOMO_CONFIG in settings with the credentials
3. Then use request_to_pay() for payments
"""
import requests
import uuid
import base64
import logging
import time
from django.conf import settings

logger = logging.getLogger(__name__)

class MTNMobileMoneyAPI:
    def __init__(self):
        # MTN Mobile Money configuration
        self.base_url = settings.MTN_MOMO_CONFIG.get('BASE_URL', 'https://sandbox.momodeveloper.mtn.com')
        self.subscription_key = settings.MTN_MOMO_CONFIG.get('SUBSCRIPTION_KEY', '')
        self.user_id = settings.MTN_MOMO_CONFIG.get('USER_ID', '')
        self.api_key = settings.MTN_MOMO_CONFIG.get('API_KEY', '')
        self.target_environment = settings.MTN_MOMO_CONFIG.get('TARGET_ENVIRONMENT', 'sandbox')
        self.callback_host = settings.MTN_MOMO_CONFIG.get('CALLBACK_HOST', 'food-delivery-backend-2mcb.onrender.com')
        self.callback_url = settings.MTN_MOMO_CONFIG.get('CALLBACK_URL', f"https://{self.callback_host}/api/payments/mtn/callback/")
        
        logger.info(f"🔑 MTN Config - Key: {self.subscription_key[:8]}... User: {self.user_id}")
        logger.info("🚀 DEPLOYMENT TEST: MTN API v2.1 - Enhanced Debugging Active")
        
        # Enhanced credential validation
        logger.info("🔍 MTN Credential Validation:")
        logger.info(f"   Subscription Key: {'✅ Present' if self.subscription_key and len(self.subscription_key) > 10 else '❌ Missing/Invalid'}")
        logger.info(f"   User ID: {'✅ Present' if self.user_id and len(self.user_id) > 10 else '❌ Missing/Invalid'}")
        logger.info(f"   API Key: {'✅ Present' if self.api_key and len(self.api_key) > 10 else '❌ Missing/Invalid'}")
        logger.info(f"   Callback Host: {self.callback_host}")
        
        # Validate credentials
        if not all([self.subscription_key, self.user_id, self.api_key]):
            logger.error("❌ Missing MTN credentials!")
            raise Exception("Missing MTN API credentials")
            
        # Check for default placeholder values
        if (self.subscription_key == 'your_subscription_key_here' or 
            self.user_id == 'your_user_id_here' or 
            self.api_key == 'your_api_key_here'):
            logger.error("❌ MTN credentials still contain placeholder values!")
            raise Exception("MTN API credentials not properly configured")
    
    def _create_api_user(self):
        """
        Step 1: Create API user as per MTN documentation
        This must be done before any API calls
        """
        try:
            url = f"{self.base_url}/v1_0/apiuser"
            
            # Generate unique reference ID for API user creation
            reference_id = str(uuid.uuid4())
            
            headers = {
                'X-Reference-Id': reference_id,
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'Content-Type': 'application/json'
            }
            
            payload = {
                "providerCallbackHost": self.callback_host
            }
            
            logger.info(f"👤 Creating API User with Reference: {reference_id}")
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"API User Creation Response: {response.status_code}")
            
            if response.status_code == 201:
                logger.info("✅ API User created successfully")
                return True
            elif response.status_code == 409:
                logger.info("✅ API User already exists")
                return True
            else:
                logger.error(f"❌ Failed to create API user: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ API user creation error: {str(e)}")
            return False
    
    def _get_or_create_api_key(self):
        """
        Step 2: Create API key for the user
        This is different from the static API key in settings
        """
        try:
            url = f"{self.base_url}/v1_0/apiuser/{self.user_id}/apikey"
            
            headers = {
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            logger.info("🔑 Creating API Key...")
            response = requests.post(url, headers=headers, timeout=30)
            
            logger.info(f"API Key Creation Response: {response.status_code}")
            
            if response.status_code == 201:
                data = response.json()
                api_key = data.get('apiKey')
                logger.info("✅ API Key created successfully")
                return api_key
            else:
                logger.error(f"❌ Failed to create API key: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"❌ API key creation error: {str(e)}")
            return None
    
    def _provision_api_user(self):
        """
        Complete API user provisioning process
        This must be completed before making payment requests
        """
        try:
            # Step 1: Create API User
            if not self._create_api_user():
                return False
            
            # Step 2: Create API Key
            dynamic_api_key = self._get_or_create_api_key()
            if not dynamic_api_key:
                return False
            
            # Update the API key to use the dynamically generated one
            self.api_key = dynamic_api_key
            logger.info("✅ API User provisioning completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ API user provisioning failed: {str(e)}")
            return False
    
    def get_access_token(self):
        """Get OAuth access token from MTN using pre-configured credentials"""
        try:
            url = f"{self.base_url}/collection/token/"
            
            # Create basic auth header using USER_ID and API_KEY from settings
            # These should be configured once during setup, not regenerated
            credentials = f"{self.user_id}:{self.api_key}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                'Authorization': f'Basic {encoded_credentials}',
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            logger.info("🔑 Requesting access token with configured credentials...")
            logger.info(f"   Using User ID: {self.user_id}")
            logger.info(f"   Using API Key: {self.api_key[:8]}...{self.api_key[-4:]}")
            
            response = requests.post(url, headers=headers, timeout=30)
            
            logger.info(f"Token Response Status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                token = data.get('access_token')
                expires_in = data.get('expires_in', 3600)
                logger.info(f"✅ Access token obtained (expires in {expires_in}s)")
                return token
            else:
                logger.error(f"❌ Token request failed: {response.status_code} - {response.text}")
                if response.status_code == 401:
                    logger.error("🔐 401 Unauthorized - Invalid API User ID or API Key")
                    logger.error("   Please verify MTN_MOMO_CONFIG credentials in settings")
                elif response.status_code == 403:
                    logger.error("🔐 403 Forbidden - Invalid Subscription Key")
                elif response.status_code == 404:
                    logger.error("🔐 404 Not Found - API User may not exist")
                    logger.error("   You may need to provision API user first")
                return None
                
        except Exception as e:
            logger.error(f"💥 Token error: {str(e)}")
            import traceback
            logger.error(f"📄 Token error traceback: {traceback.format_exc()}")
            return None
    
    def _validate_and_format_phone_number(self, phone_number):
        """
        Validate and format phone number for MTN Uganda
        """
        # Remove any spaces, dashes, or other characters
        cleaned = ''.join(filter(str.isdigit, str(phone_number)))
        
        # Handle different formats
        if cleaned.startswith('0') and len(cleaned) == 10:  # 0783876390
            formatted = '256' + cleaned[1:]  # 256783876390
        elif cleaned.startswith('256') and len(cleaned) == 12:  # 256783876390
            formatted = cleaned
        elif cleaned.startswith('+256') and len(cleaned) == 13:  # +256783876390
            formatted = cleaned[1:]  # 256783876390
        else:
            logger.error(f"❌ Invalid phone number format: {phone_number}")
            return None
        
        logger.info(f"📱 Phone formatted: {phone_number} -> {formatted}")
        return formatted
    
    def _validate_and_format_amount(self, amount):
        """
        Validate and format amount for MTN API
        MTN expects amount as string without decimal places for UGX
        """
        try:
            # Convert to float first to handle string inputs
            amount_float = float(amount)
            
            # Validate minimum amount
            if amount_float < 100:  # MTN minimum is usually 100 UGX
                logger.error(f"❌ Amount {amount_float} is below MTN minimum of 100 UGX")
                return None
            
            # Convert to integer string (remove decimals)
            amount_str = str(int(amount_float))
            
            logger.info(f"💰 Amount formatted: {amount} -> {amount_str}")
            return amount_str
            
        except (ValueError, TypeError) as e:
            logger.error(f"❌ Invalid amount format: {amount} - {str(e)}")
            return None
    
    def request_to_pay(self, phone_number, amount, external_id, payer_message="Food Delivery Payment"):
        """
        Request payment from MTN Mobile Money user - CORRECTED VERSION
        """
        logger.info("🚀 DEPLOYMENT TEST: request_to_pay v2.0 called")
        try:
            logger.info("🚀 Starting MTN Mobile Money payment process...")
            
            # Step 1: Validate and format inputs
            logger.info("🔧 Step 1: Validating phone number...")
            try:
                formatted_phone = self._validate_and_format_phone_number(phone_number)
                if not formatted_phone:
                    return {
                        'success': False,
                        'error': 'Invalid phone number format'
                    }
                logger.info(f"✅ Phone validation successful: {formatted_phone}")
            except Exception as phone_error:
                logger.error(f"❌ Phone validation failed: {phone_error}")
                return {
                    'success': False,
                    'error': f'Phone validation error: {phone_error}'
                }
            
            logger.info("🔧 Step 2: Validating amount...")
            try:
                formatted_amount = self._validate_and_format_amount(amount)
                if not formatted_amount:
                    return {
                        'success': False,
                        'error': 'Invalid amount format'
                    }
                logger.info(f"✅ Amount validation successful: {formatted_amount}")
            except Exception as amount_error:
                logger.error(f"❌ Amount validation failed: {amount_error}")
                return {
                    'success': False,
                    'error': f'Amount validation error: {amount_error}'
                }
            
            # Step 3: Get access token
            logger.info("🔧 Step 3: Getting access token...")
            try:
                token = self.get_access_token()
                if not token:
                    return {
                        'success': False,
                        'error': 'Failed to obtain access token'
                    }
                logger.info(f"✅ Token obtained successfully: {token[:20]}...")
            except Exception as token_error:
                logger.error(f"❌ Token generation failed: {token_error}")
                import traceback
                logger.error(f"📄 Token error traceback: {traceback.format_exc()}")
                return {
                    'success': False,
                    'error': f'Token generation error: {token_error}'
                }
            
            # Step 3: Prepare payment request
            url = f"{self.base_url}/collection/v1_0/requesttopay"
            
            # Generate unique reference ID
            reference_id = str(uuid.uuid4())
            
            # Truncate messages to MTN limits
            truncated_payer_message = payer_message[:20]
            truncated_payee_note = f"Order {external_id}"[:20]
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Reference-Id': reference_id,
                'X-Target-Environment': self.target_environment,
                'Ocp-Apim-Subscription-Key': self.subscription_key,
                'Content-Type': 'application/json',
            }

            # Some environments require explicit callback URL header; add if available
            if self.callback_url:
                headers['X-Callback-Url'] = self.callback_url
            
            payload = {
                "amount": formatted_amount,
                "currency": "UGX",
                "externalId": external_id,
                "payer": {
                    "partyIdType": "MSISDN",
                    "partyId": formatted_phone
                },
                "payerMessage": truncated_payer_message,
                "payeeNote": truncated_payee_note
            }
            
            logger.info("📤 Sending MTN Payment Request:")
            logger.info(f"URL: {url}")
            logger.info(f"Reference ID: {reference_id}")
            logger.info(f"Phone: {formatted_phone}")
            logger.info(f"Amount: {formatted_amount} UGX")
            logger.info(f"Headers: {headers}")
            logger.info(f"Payload: {payload}")
            
            # Additional validation before sending
            logger.info("🔍 Pre-flight validation:")
            logger.info(f"   Token length: {len(token) if token else 0}")
            logger.info(f"   Reference ID format: {reference_id}")
            logger.info(f"   Phone format check: {formatted_phone}")
            logger.info(f"   Amount type: {type(formatted_amount)} = {formatted_amount}")
            logger.info(f"   External ID: {external_id}")
            
            # Step 4: Make API call
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"📥 MTN API Response:")
            logger.info(f"Status Code: {response.status_code}")
            logger.info(f"Response Headers: {dict(response.headers)}")
            logger.info(f"Response Body: {response.text}")
            
            # Step 5: Handle response
            if response.status_code == 202:
                logger.info("✅ Payment request accepted - USSD prompt sent to user")
                
                # Wait a moment and check payment status
                time.sleep(2)
                payment_status = self.check_payment_status(reference_id)
                
                return {
                    'success': True,
                    'reference_id': reference_id,
                    'message': 'Payment request sent. Please check your phone and enter your PIN.',
                    'status_response': payment_status
                }
                
            elif response.status_code == 400:
                # Enhanced 400 error analysis
                logger.error("❌ MTN API 400 Bad Request - Detailed Analysis:")
                logger.error(f"   Response Headers: {dict(response.headers)}")
                logger.error(f"   Response Body: '{response.text}'")
                logger.error(f"   Response Length: {len(response.text)}")
                logger.error(f"   Content-Type: {response.headers.get('content-type', 'Not specified')}")
                
                # Try to parse error details
                error_info = response.text
                error_details = {}
                
                try:
                    if response.text.strip():
                        error_json = response.json()
                        error_details = error_json
                        error_info = str(error_json)
                        logger.error(f"   Parsed JSON Error: {error_json}")
                    else:
                        logger.error("   Empty response body - no error details provided by MTN")
                        error_info = "Empty response body"
                except Exception as parse_error:
                    logger.error(f"   Failed to parse error response: {parse_error}")
                    error_info = f"Unparseable response: {response.text}"
                
                # Log the exact request that failed for debugging
                logger.error("🔍 Failed Request Details:")
                logger.error(f"   URL: {url}")
                logger.error(f"   Method: POST")
                logger.error(f"   Headers sent: {headers}")
                logger.error(f"   Payload sent: {payload}")
                
                return {
                    'success': False,
                    'error': f'Invalid request parameters: {error_info}',
                    'status_code': 400,
                    'raw_response': response.text,
                    'error_details': error_details
                }
                
            else:
                logger.error(f"❌ MTN API Error: {response.status_code}")
                return {
                    'success': False,
                    'error': f'MTN API Error: {response.status_code} - {response.text}',
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
                logger.error("❌ Cannot check status: No access token")
                return None
            
            url = f"{self.base_url}/collection/v1_0/requesttopay/{reference_id}"
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Target-Environment': self.target_environment,
                'Ocp-Apim-Subscription-Key': self.subscription_key
            }
            
            logger.info(f"🔍 Checking payment status for: {reference_id}")
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                status_data = response.json()
                logger.info(f"✅ Payment status: {status_data}")
                return status_data
            else:
                logger.error(f"❌ Status check failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Status check error: {str(e)}")
            return None
