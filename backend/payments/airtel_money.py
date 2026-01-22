"""
Airtel Money Uganda Integration - v1.0
Direct integration with Airtel Money API for Uganda
Created: November 7, 2025

IMPORTANT: Before using this integration:
1. Sign up for Airtel Money API access at https://developers.airtel.africa
2. Get your CLIENT_ID and CLIENT_SECRET from the developer portal
3. Configure AIRTEL_MONEY_CONFIG in Django settings
4. Use request_to_pay() for payment requests
"""
import requests
import json
import re
import uuid
import base64
import logging
import time
from django.conf import settings

logger = logging.getLogger(__name__)

class AirtelMoneyAPI:
    def __init__(self):
        """Initialize Airtel Money API with configuration from settings"""
        # Airtel Money configuration
        self.base_url = settings.AIRTEL_MONEY_CONFIG.get('BASE_URL', 'https://openapiuat.airtel.africa')
        self.client_id = settings.AIRTEL_MONEY_CONFIG.get('CLIENT_ID', '')
        self.client_secret = settings.AIRTEL_MONEY_CONFIG.get('CLIENT_SECRET', '')
        self.grant_type = settings.AIRTEL_MONEY_CONFIG.get('GRANT_TYPE', 'client_credentials')
        self.env = settings.AIRTEL_MONEY_CONFIG.get('ENV', 'staging')  # staging or production
        self.country = settings.AIRTEL_MONEY_CONFIG.get('COUNTRY', 'UG')  # Uganda
        self.currency = settings.AIRTEL_MONEY_CONFIG.get('CURRENCY', 'UGX')
        
        logger.info("🟥 Airtel Money API Initialization")
        logger.info(f"   Environment: {self.env}")
        logger.info(f"   Country: {self.country}")
        logger.info(f"   Currency: {self.currency}")
        
        # Enhanced credential validation
        logger.info("🔍 Airtel Credential Validation:")
        logger.info(f"   Client ID: {'✅ Present' if self.client_id and len(self.client_id) > 10 else '❌ Missing/Invalid'}")
        logger.info(f"   Client Secret: {'✅ Present' if self.client_secret and len(self.client_secret) > 10 else '❌ Missing/Invalid'}")
        
        # Validate credentials
        if not all([self.client_id, self.client_secret]):
            logger.error("❌ Missing Airtel Money credentials!")
            raise Exception("Missing Airtel Money API credentials")
            
        # Check for default placeholder values
        if (self.client_id == 'your_client_id_here' or 
            self.client_secret == 'your_client_secret_here'):
            logger.error("❌ Airtel credentials still contain placeholder values!")
            raise Exception("Airtel Money API credentials not properly configured")
    
    def get_access_token(self):
        """
        Get OAuth2 access token from Airtel Money API
        Airtel uses client_credentials grant type
        """
        try:
            url = f"{self.base_url}/auth/oauth2/token"
            
            headers = {
                'Content-Type': 'application/json',
                'Accept': '*/*'
            }
            
            payload = {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "grant_type": self.grant_type
            }
            
            logger.info("🔑 Requesting Airtel access token...")
            logger.info(f"   URL: {url}")
            logger.info(f"   Client ID: {self.client_id[:8]}...{self.client_id[-4:]}")
            
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"Token Response Status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                token = data.get('access_token')
                expires_in = data.get('expires_in', 3600)
                logger.info(f"✅ Airtel access token obtained (expires in {expires_in}s)")
                return token
            else:
                logger.error(f"❌ Airtel token request failed: {response.status_code}")
                logger.error(f"   Response: {response.text}")
                if response.status_code == 401:
                    logger.error("🔐 401 Unauthorized - Invalid CLIENT_ID or CLIENT_SECRET")
                elif response.status_code == 403:
                    logger.error("🔐 403 Forbidden - Access denied")
                return None
                
        except Exception as e:
            logger.error(f"💥 Airtel token error: {str(e)}")
            import traceback
            logger.error(f"📄 Token error traceback: {traceback.format_exc()}")
            return None
    
    def _validate_and_format_phone_number(self, phone_number):
        """
        Validate and format phone number for Airtel Uganda
        Airtel numbers: 070X, 075X
        """
        # Remove any spaces, dashes, or other characters
        cleaned = ''.join(filter(str.isdigit, str(phone_number)))
        
        # Handle different formats
        if cleaned.startswith('0') and len(cleaned) == 10:  # 0701234567
            formatted = '256' + cleaned[1:]  # 256701234567
        elif cleaned.startswith('256') and len(cleaned) == 12:  # 256701234567
            formatted = cleaned
        elif cleaned.startswith('+256') and len(cleaned) == 13:  # +256701234567
            formatted = cleaned[1:]  # 256701234567
        else:
            logger.error(f"❌ Invalid phone number format: {phone_number}")
            return None
        
        # Validate Airtel prefix (70 or 75)
        if not (formatted[3:5] in ['70', '75']):
            logger.error(f"❌ Not an Airtel number: {phone_number} (must start with 070 or 075)")
            return None
        
        logger.info(f"📱 Airtel phone formatted: {phone_number} -> {formatted}")
        return formatted
    
    def _validate_and_format_amount(self, amount):
        """
        Validate and format amount for Airtel Money API
        Airtel expects numeric string for UGX
        """
        try:
            # Convert to float first to handle string inputs
            amount_float = float(amount)
            
            # Validate minimum amount (Airtel minimum is usually 500 UGX)
            if amount_float < 500:
                logger.error(f"❌ Amount {amount_float} is below Airtel minimum of 500 UGX")
                return None
            
            # Convert to integer string (remove decimals)
            amount_str = str(int(amount_float))
            
            logger.info(f"💰 Airtel amount formatted: {amount} -> {amount_str}")
            return amount_str
            
        except (ValueError, TypeError) as e:
            logger.error(f"❌ Invalid amount format: {amount} - {str(e)}")
            return None
    
    def request_to_pay(self, phone_number, amount, external_id, reference="Food Delivery Payment"):
        """
        Request payment from Airtel Money user
        
        Args:
            phone_number: Customer's Airtel phone number
            amount: Amount in UGX
            external_id: Your unique transaction ID
            reference: Payment description
            
        Returns:
            dict: Payment response with success status
        """
        logger.info("🟥 Starting Airtel Money payment process...")
        try:
            # Step 1: Validate and format inputs
            logger.info("🔧 Step 1: Validating phone number...")
            formatted_phone = self._validate_and_format_phone_number(phone_number)
            if not formatted_phone:
                return {
                    'success': False,
                    'error': 'Invalid Airtel phone number format. Must start with 070 or 075'
                }
            logger.info(f"✅ Phone validation successful: {formatted_phone}")
            
            logger.info("🔧 Step 2: Validating amount...")
            formatted_amount = self._validate_and_format_amount(amount)
            if not formatted_amount:
                return {
                    'success': False,
                    'error': 'Invalid amount. Minimum 500 UGX required'
                }
            logger.info(f"✅ Amount validation successful: {formatted_amount}")
            
            # Step 3: Get access token
            logger.info("🔧 Step 3: Getting access token...")
            token = self.get_access_token()
            if not token:
                return {
                    'success': False,
                    'error': 'Failed to obtain Airtel access token'
                }
            logger.info(f"✅ Token obtained successfully")
            
            # Step 4: Prepare payment request
            url = f"{self.base_url}/merchant/v1/payments/"
            
            # Generate unique transaction ID
            transaction_id = str(uuid.uuid4())
            
            headers = {
                'Content-Type': 'application/json',
                'Accept': '*/*',
                'Authorization': f'Bearer {token}',
                'X-Country': self.country,
                'X-Currency': self.currency
            }
            
            # Airtel Money payload structure
            payload = {
                "reference": external_id,
                "subscriber": {
                    "country": self.country,
                    "currency": self.currency,
                    "msisdn": formatted_phone
                },
                "transaction": {
                    "amount": formatted_amount,
                    "country": self.country,
                    "currency": self.currency,
                    "id": transaction_id
                }
            }
            
            logger.info("📤 Sending Airtel Payment Request:")
            logger.info(f"   URL: {url}")
            logger.info(f"   Transaction ID: {transaction_id}")
            logger.info(f"   Phone: {formatted_phone}")
            logger.info(f"   Amount: {formatted_amount} UGX")
            logger.info(f"   Reference: {external_id}")
            logger.info(f"   Payload: {json.dumps(payload, indent=2)}")
            
            # Step 5: Make API call
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            logger.info(f"📥 Airtel API Response:")
            logger.info(f"   Status Code: {response.status_code}")
            logger.info(f"   Response: {response.text}")
            
            # Step 6: Handle response
            if response.status_code in [200, 201]:
                response_data = response.json()
                
                # Airtel returns transaction status
                if response_data.get('status', {}).get('success') or response_data.get('data', {}).get('transaction', {}).get('status') == 'TS':
                    logger.info("✅ Payment request accepted - USSD prompt sent to user")
                    
                    # Extract transaction details
                    airtel_transaction_id = response_data.get('data', {}).get('transaction', {}).get('airtel_money_id', transaction_id)
                    
                    # Wait and check status
                    time.sleep(2)
                    payment_status = self.check_payment_status(airtel_transaction_id, token)
                    
                    return {
                        'success': True,
                        'reference_id': airtel_transaction_id,
                        'transaction_id': transaction_id,
                        'message': 'Payment request sent. Please check your phone and enter your PIN.',
                        'status_response': payment_status
                    }
                else:
                    error_message = response_data.get('status', {}).get('message', 'Unknown error')
                    logger.error(f"❌ Airtel payment failed: {error_message}")
                    return {
                        'success': False,
                        'error': f'Payment failed: {error_message}',
                        'raw_response': response_data
                    }
                    
            elif response.status_code == 400:
                logger.error("❌ Airtel API 400 Bad Request")
                try:
                    error_data = response.json()
                    error_message = error_data.get('status', {}).get('message', response.text)
                except:
                    error_message = response.text
                
                return {
                    'success': False,
                    'error': f'Invalid request: {error_message}',
                    'status_code': 400
                }
                
            elif response.status_code == 401:
                logger.error("❌ Airtel API 401 Unauthorized - Token expired or invalid")
                return {
                    'success': False,
                    'error': 'Authentication failed. Please try again.',
                    'status_code': 401
                }
                
            else:
                logger.error(f"❌ Airtel API Error: {response.status_code}")
                return {
                    'success': False,
                    'error': f'Airtel API Error: {response.status_code} - {response.text}',
                    'status_code': response.status_code
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
    
    def check_payment_status(self, transaction_id, token=None):
        """
        Check the status of an Airtel Money transaction
        
        Args:
            transaction_id: Airtel transaction ID
            token: Access token (optional, will generate if not provided)
        """
        try:
            # Get token if not provided
            if not token:
                token = self.get_access_token()
                if not token:
                    logger.error("❌ Cannot check status: No access token")
                    return None
            
            url = f"{self.base_url}/standard/v1/payments/{transaction_id}"
            
            headers = {
                'Authorization': f'Bearer {token}',
                'X-Country': self.country,
                'X-Currency': self.currency
            }
            
            logger.info(f"🔍 Checking Airtel payment status for: {transaction_id}")
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                status_data = response.json()
                logger.info(f"✅ Airtel payment status: {status_data}")
                
                # Parse Airtel status
                transaction_status = status_data.get('data', {}).get('transaction', {}).get('status')
                status_mapping = {
                    'TS': 'SUCCESSFUL',
                    'TF': 'FAILED',
                    'TA': 'AMBIGUOUS',
                    'TIP': 'IN_PROGRESS'
                }
                
                readable_status = status_mapping.get(transaction_status, transaction_status)
                logger.info(f"   Transaction Status: {readable_status}")
                
                return status_data
            else:
                logger.error(f"❌ Airtel status check failed: {response.status_code}")
                logger.error(f"   Response: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Airtel status check error: {str(e)}")
            return None
    
    def refund_payment(self, transaction_id, amount):
        """
        Refund an Airtel Money transaction
        
        Args:
            transaction_id: Original transaction ID
            amount: Amount to refund
        """
        try:
            token = self.get_access_token()
            if not token:
                logger.error("❌ Cannot refund: No access token")
                return {'success': False, 'error': 'Authentication failed'}
            
            url = f"{self.base_url}/standard/v1/payments/refund"
            
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
                'X-Country': self.country,
                'X-Currency': self.currency
            }
            
            payload = {
                "transaction": {
                    "airtel_money_id": transaction_id,
                    "amount": str(int(float(amount))),
                    "country": self.country,
                    "currency": self.currency
                }
            }
            
            logger.info(f"💸 Initiating Airtel Money refund...")
            logger.info(f"   Transaction ID: {transaction_id}")
            logger.info(f"   Amount: {amount}")
            
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            
            if response.status_code == 200:
                refund_data = response.json()
                logger.info(f"✅ Refund successful: {refund_data}")
                return {
                    'success': True,
                    'data': refund_data
                }
            else:
                logger.error(f"❌ Refund failed: {response.status_code} - {response.text}")
                return {
                    'success': False,
                    'error': response.text
                }
                
        except Exception as e:
            logger.error(f"❌ Refund error: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
