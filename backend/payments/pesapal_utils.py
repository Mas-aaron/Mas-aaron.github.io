import requests
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)

class PesaPalAPI:
    def __init__(self):
        self.consumer_key = settings.PESAPAL_CONFIG['CONSUMER_KEY']
        self.consumer_secret = settings.PESAPAL_CONFIG['CONSUMER_SECRET']
        self.base_url = settings.PESAPAL_CONFIG['API_URL']
        self.callback_url = settings.PESAPAL_CONFIG['CALLBACK_URL']
        self.ipn_url = settings.PESAPAL_CONFIG['IPN_URL']
    
    def get_access_token(self):
        """Get access token from PesaPal"""
        try:
            url = f"{self.base_url}/api/Auth/RequestToken"
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            payload = {
                'consumer_key': self.consumer_key,
                'consumer_secret': self.consumer_secret
            }
            
            logger.info(f"Requesting PesaPal token from: {url}")
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            token = data.get('token')
            logger.info("Successfully obtained PesaPal access token")
            return token
            
        except requests.exceptions.RequestException as e:
            logger.error(f"PesaPal token request failed: {str(e)}")
            if hasattr(e, 'response') and e.response:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response text: {e.response.text}")
            return None
    
    def submit_order(self, order_data):
        """Submit order to PesaPal"""
        try:
            token = self.get_access_token()
            if not token:
                raise Exception("Failed to get access token")
            
            url = f"{self.base_url}/api/Transactions/SubmitOrderRequest"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            logger.info(f"Submitting order to PesaPal: {order_data}")
            response = requests.post(url, json=order_data, headers=headers, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            logger.info(f"PesaPal order submission response: {data}")
            return data
            
        except requests.exceptions.RequestException as e:
            logger.error(f"PesaPal order submission failed: {str(e)}")
            if hasattr(e, 'response') and e.response:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response text: {e.response.text}")
            raise Exception(f"PesaPal order submission failed: {str(e)}")
    
    def get_transaction_status(self, order_tracking_id):
        """Get transaction status from PesaPal"""
        try:
            token = self.get_access_token()
            if not token:
                raise Exception("Failed to get access token")
            
            url = f"{self.base_url}/api/Transactions/GetTransactionStatus"
            params = {'orderTrackingId': order_tracking_id}
            headers = {
                'Authorization': f'Bearer {token}',
                'Accept': 'application/json'
            }
            
            response = requests.get(url, params=params, headers=headers, timeout=30)
            response.raise_for_status()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            logger.error(f"PesaPal status check failed: {str(e)}")
            return None
