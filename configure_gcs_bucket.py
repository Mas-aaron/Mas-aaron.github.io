#!/usr/bin/env python3
"""
Script to configure GCS bucket for public access
Run this script to make the bucket publicly accessible for image serving
"""
import os
import json
import tempfile
from google.cloud import storage
from google.oauth2 import service_account

def configure_bucket_public_access():
    """Configure the GCS bucket to allow public read access"""
    
    # Get credentials from environment (same as Django uses)
    credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
    if not credentials_json:
        print("❌ GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable not found")
        print("This script should be run on the server where the environment variables are set")
        return False
    
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
        
        print(f"🔧 Configuring bucket: {bucket_name}")
        
        # Check if bucket exists
        if not bucket.exists():
            print(f"❌ Bucket {bucket_name} does not exist")
            return False
        
        # Make bucket publicly readable
        print("📝 Setting IAM policy for public read access...")
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
            print("✅ Bucket configured for public read access")
        else:
            print("✅ Bucket already has public read access")
        
        # Set CORS configuration
        print("🌐 Configuring CORS...")
        cors_configuration = [{
            'origin': ['*'],
            'method': ['GET', 'HEAD'],
            'responseHeader': ['Content-Type'],
            'maxAgeSeconds': 3600
        }]
        
        bucket.cors = cors_configuration
        bucket.patch()
        print("✅ CORS configuration applied")
        
        # Test by listing some objects
        print("🔍 Testing bucket access...")
        blobs = list(bucket.list_blobs(max_results=5))
        print(f"📁 Found {len(blobs)} objects in bucket")
        
        if blobs:
            test_blob = blobs[0]
            public_url = f"https://storage.googleapis.com/{bucket_name}/{test_blob.name}"
            print(f"🔗 Test public URL: {public_url}")
        
        # Clean up temp file
        os.unlink(temp_cred_path)
        
        print("🎉 Bucket configuration completed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Error configuring bucket: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 Starting GCS bucket configuration...")
    success = configure_bucket_public_access()
    
    if success:
        print("\n✅ Configuration completed! Images should now be publicly accessible.")
        print("💡 Test by uploading an image through the Django API and accessing the returned URL.")
    else:
        print("\n❌ Configuration failed. Please check the error messages above.")
        print("💡 Make sure GOOGLE_APPLICATION_CREDENTIALS_JSON is set in your environment.")
