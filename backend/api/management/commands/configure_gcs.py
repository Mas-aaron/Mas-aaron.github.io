from django.core.management.base import BaseCommand
import os
import json
import tempfile
from google.cloud import storage
from google.oauth2 import service_account

class Command(BaseCommand):
    help = 'Configure GCS bucket for public access'

    def handle(self, *args, **options):
        self.stdout.write("🚀 Starting GCS bucket configuration...")
        
        # Get credentials from environment (same as Django uses)
        credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
        if not credentials_json:
            self.stdout.write(self.style.ERROR("❌ GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable not found"))
            return
        
        try:
            # Parse credentials
            credentials_info = json.loads(credentials_json)
            
            # Create temporary credential file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_file:
                json.dump(credentials_info, temp_file)
                temp_file.flush()
                temp_cred_path = temp_file.name
            
            # Initialize client
            credentials = service_account.Credentials.from_service_account_file(temp_cred_path)
            client = storage.Client(credentials=credentials, project=credentials_info.get('project_id'))
            
            bucket_name = 'storage-bucket-fortexpress'
            bucket = client.bucket(bucket_name)
            
            self.stdout.write(f"🔧 Configuring bucket: {bucket_name}")
            
            # Check if bucket exists
            if not bucket.exists():
                self.stdout.write(self.style.ERROR(f"❌ Bucket {bucket_name} does not exist"))
                return
            
            # Make bucket publicly readable
            self.stdout.write("📝 Setting IAM policy for public read access...")
            policy = bucket.get_iam_policy(requested_policy_version=3)
            
            # Check if allUsers already has access
            has_public_access = False
            for binding in policy.bindings:
                if binding['role'] == 'roles/storage.objectViewer' and 'allUsers' in binding.get('members', []):
                    has_public_access = True
                    break
            
            if not has_public_access:
                # Add allUsers as a viewer
                policy.bindings.append({
                    "role": "roles/storage.objectViewer",
                    "members": {"allUsers"}
                })
                bucket.set_iam_policy(policy)
                self.stdout.write(self.style.SUCCESS("✅ Bucket configured for public read access"))
            else:
                self.stdout.write(self.style.SUCCESS("✅ Bucket already has public read access"))
            
            # Set CORS configuration
            self.stdout.write("🌐 Configuring CORS...")
            cors_configuration = [{
                'origin': ['*'],
                'method': ['GET', 'HEAD'],
                'responseHeader': ['Content-Type'],
                'maxAgeSeconds': 3600
            }]
            
            bucket.cors = cors_configuration
            bucket.patch()
            self.stdout.write(self.style.SUCCESS("✅ CORS configuration applied"))
            
            # Test by listing some objects
            self.stdout.write("🔍 Testing bucket access...")
            blobs = list(bucket.list_blobs(max_results=5))
            self.stdout.write(f"📁 Found {len(blobs)} objects in bucket")
            
            if blobs:
                test_blob = blobs[0]
                public_url = f"https://storage.googleapis.com/{bucket_name}/{test_blob.name}"
                self.stdout.write(f"🔗 Test public URL: {public_url}")
            
            # Clean up temp file
            os.unlink(temp_cred_path)
            
            self.stdout.write(self.style.SUCCESS("🎉 Bucket configuration completed successfully!"))
            self.stdout.write("💡 Test by uploading an image through the Django API and accessing the returned URL.")
            
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"❌ Error configuring bucket: {e}"))
            import traceback
            traceback.print_exc()
