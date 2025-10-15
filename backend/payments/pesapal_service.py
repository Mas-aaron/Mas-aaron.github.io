import requests
from django.conf import settings

class PesapalService:
    def __init__(self):
        self.base_url = settings.PESAPAL_BASE_URL
        self.consumer_key = settings.PESAPAL_CONSUMER_KEY
        self.consumer_secret = settings.PESAPAL_CONSUMER_SECRET

    def generate_access_token(self):
        url = f"{self.base_url}/Auth/RequestToken"
        payload = {
            "consumer_key": self.consumer_key,
            "consumer_secret": self.consumer_secret
        }
        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
        response = requests.post(url, json=payload, headers=headers)
        return response.json().get("token") if response.status_code == 200 else None

    def submit_order_request(self, payload):
        token = self.generate_access_token()
        url = f"{self.base_url}/Transactions/SubmitOrderRequest"
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
        return requests.post(url, json=payload, headers=headers).json()

    def get_transaction_status(self, tracking_id, merchant_reference):
        token = self.generate_access_token()
        url = f"{self.base_url}/Transactions/GetTransactionStatus"
        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json"
        }
        params = {
            "orderTrackingId": tracking_id,
            "merchantReference": merchant_reference
        }
        response = requests.get(url, headers=headers, params=params)
        return response.json() if response.status_code == 200 else None
