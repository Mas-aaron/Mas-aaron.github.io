#!/usr/bin/env python3
"""
Test GCS connection and credentials
"""
import os
import sys
import django
import tempfile
import json
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_dir))

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from google.cloud import storage
from google.oauth2 import service_account

def test_gcs_connection():
    """Test if GCS credentials and bucket access work"""
    
    print("🔍 Testing GCS connection...")
    
    # Check if credentials are available
    credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
    if not credentials_json:
        print("❌ GOOGLE_APPLICATION_CREDENTIALS_JSON not found in environment")
        return False
    
    try:
        # Parse credentials
        credentials_info = json.loads(credentials_json)
        print(f"✅ Credentials loaded for project: {credentials_info.get('project_id')}")
        
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
        
        # Test bucket access
        print(f"🔍 Testing bucket access: {bucket_name}")
        if not bucket.exists():
            print(f"❌ Bucket {bucket_name} does not exist or is not accessible")
            return False
        
        print(f"✅ Bucket {bucket_name} is accessible")
        
        # Test upload
        print("🔍 Testing file upload...")
        test_content = b"Test file content for GCS upload"
        blob_name = "test_uploads/test_file.txt"
        
        blob = bucket.blob(blob_name)
        blob.upload_from_string(test_content, content_type='text/plain')
        
        print(f"✅ Test file uploaded: {blob_name}")
        
        # Test public access
        try:
            blob.acl.all().grant_read()
            blob.acl.save()
            print(f"✅ Made test file public")
        except Exception as acl_error:
            print(f"⚠️ Could not set ACL: {acl_error}")
        
        # List objects
        blobs = list(bucket.list_blobs(max_results=10))
        print(f"📁 Found {len(blobs)} objects in bucket:")
        for blob in blobs:
            print(f"  - {blob.name}")
        
        # Clean up temp file
        os.unlink(temp_cred_path)
        
        print("🎉 GCS connection test successful!")
        return True
        
    except Exception as e:
        print(f"❌ GCS connection test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_gcs_connection()
    if not success:
        print("\n💡 Possible issues:")
        print("1. GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable not set")
        print("2. Invalid or expired service account credentials")
        print("3. Service account lacks permissions for the bucket")
        print("4. Bucket name or project ID mismatch")
