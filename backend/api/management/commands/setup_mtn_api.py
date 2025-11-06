"""
Management command to set up and test MTN Mobile Money API integration
"""
from django.core.management.base import BaseCommand
from django.conf import settings
import requests
import uuid
import base64


class Command(BaseCommand):
    help = 'Setup and test MTN Mobile Money API integration'

    def add_arguments(self, parser):
        parser.add_argument(
            '--create-user',
            action='store_true',
            help='Create a new API user',
        )
        parser.add_argument(
            '--test-credentials',
            action='store_true',
            help='Test existing credentials',
        )
        parser.add_argument(
            '--get-api-key',
            action='store_true',
            help='Generate API key for existing user',
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('\n=== MTN Mobile Money API Setup ===\n'))
        
        # Get MTN configuration
        mtn_config = settings.MTN_MOMO_CONFIG
        subscription_key = mtn_config.get('SUBSCRIPTION_KEY', '')
        user_id = mtn_config.get('USER_ID', '')
        api_key = mtn_config.get('API_KEY', '')
        callback_host = mtn_config.get('CALLBACK_HOST', 'food-delivery-backend-2mcb.onrender.com')
        base_url = "https://sandbox.momodeveloper.mtn.com"
        
        # Display current configuration
        self.stdout.write('\n📋 Current Configuration:')
        self.stdout.write(f'   Subscription Key: {subscription_key[:8]}...{subscription_key[-4:] if len(subscription_key) > 12 else ""}')
        self.stdout.write(f'   User ID: {user_id}')
        self.stdout.write(f'   API Key: {api_key[:8]}...{api_key[-4:] if len(api_key) > 12 else ""}')
        self.stdout.write(f'   Callback Host: {callback_host}')
        self.stdout.write(f'   Base URL: {base_url}\n')
        
        if not subscription_key or subscription_key == 'your_subscription_key_here':
            self.stdout.write(self.style.ERROR('❌ Subscription key not configured!'))
            self.stdout.write('   Get your subscription key from: https://momodeveloper.mtn.com/')
            return
        
        # Create API User
        if options['create_user']:
            self.stdout.write('\n🔧 Creating API User...')
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
            
            try:
                response = requests.post(url, json=payload, headers=headers, timeout=30)
                
                if response.status_code == 201:
                    self.stdout.write(self.style.SUCCESS(f'✅ API User created successfully!'))
                    self.stdout.write(f'   User ID (X-Reference-Id): {reference_id}')
                    self.stdout.write(self.style.WARNING('\n⚠️  IMPORTANT: Update your settings with this User ID:'))
                    self.stdout.write(f"   MTN_MOMO_CONFIG['USER_ID'] = '{reference_id}'")
                elif response.status_code == 409:
                    self.stdout.write(self.style.WARNING('⚠️  API User already exists'))
                else:
                    self.stdout.write(self.style.ERROR(f'❌ Failed: {response.status_code} - {response.text}'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'❌ Error: {str(e)}'))
        
        # Get API Key
        if options['get_api_key']:
            if not user_id or user_id == 'your_user_id_here':
                self.stdout.write(self.style.ERROR('\n❌ User ID not configured! Create user first with --create-user'))
                return
            
            self.stdout.write('\n🔑 Generating API Key...')
            url = f"{base_url}/v1_0/apiuser/{user_id}/apikey"
            headers = {
                'Ocp-Apim-Subscription-Key': subscription_key
            }
            
            try:
                response = requests.post(url, headers=headers, timeout=30)
                
                if response.status_code == 201:
                    data = response.json()
                    generated_api_key = data.get('apiKey')
                    self.stdout.write(self.style.SUCCESS('✅ API Key generated successfully!'))
                    self.stdout.write(f'   API Key: {generated_api_key}')
                    self.stdout.write(self.style.WARNING('\n⚠️  IMPORTANT: Update your settings with this API Key:'))
                    self.stdout.write(f"   MTN_MOMO_CONFIG['API_KEY'] = '{generated_api_key}'")
                else:
                    self.stdout.write(self.style.ERROR(f'❌ Failed: {response.status_code} - {response.text}'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'❌ Error: {str(e)}'))
        
        # Test credentials
        if options['test_credentials']:
            if not all([user_id, api_key]) or user_id == 'your_user_id_here' or api_key == 'your_api_key_here':
                self.stdout.write(self.style.ERROR('\n❌ User ID or API Key not configured!'))
                return
            
            self.stdout.write('\n🧪 Testing credentials...')
            url = f"{base_url}/collection/token/"
            credentials = f"{user_id}:{api_key}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                'Authorization': f'Basic {encoded_credentials}',
                'Ocp-Apim-Subscription-Key': subscription_key
            }
            
            try:
                response = requests.post(url, headers=headers, timeout=30)
                
                if response.status_code == 200:
                    data = response.json()
                    token = data.get('access_token')
                    expires_in = data.get('expires_in', 0)
                    self.stdout.write(self.style.SUCCESS('✅ Credentials are valid!'))
                    self.stdout.write(f'   Access Token: {token[:20]}...')
                    self.stdout.write(f'   Expires in: {expires_in} seconds')
                    self.stdout.write(self.style.SUCCESS('\n🎉 MTN API integration is ready to use!'))
                elif response.status_code == 401:
                    self.stdout.write(self.style.ERROR('❌ 401 Unauthorized - Invalid User ID or API Key'))
                elif response.status_code == 403:
                    self.stdout.write(self.style.ERROR('❌ 403 Forbidden - Invalid Subscription Key'))
                elif response.status_code == 404:
                    self.stdout.write(self.style.ERROR('❌ 404 Not Found - API User does not exist'))
                    self.stdout.write('   Run with --create-user to create the user')
                else:
                    self.stdout.write(self.style.ERROR(f'❌ Failed: {response.status_code} - {response.text}'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'❌ Error: {str(e)}'))
        
        # If no options specified, show help
        if not any([options['create_user'], options['test_credentials'], options['get_api_key']]):
            self.stdout.write('\n💡 Usage:')
            self.stdout.write('   Step 1: Create API User')
            self.stdout.write('   python manage.py setup_mtn_api --create-user')
            self.stdout.write('\n   Step 2: Generate API Key')
            self.stdout.write('   python manage.py setup_mtn_api --get-api-key')
            self.stdout.write('\n   Step 3: Test credentials')
            self.stdout.write('   python manage.py setup_mtn_api --test-credentials')
        
        self.stdout.write('\n')
