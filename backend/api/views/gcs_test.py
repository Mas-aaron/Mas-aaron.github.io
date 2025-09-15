from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.http import JsonResponse
import os
import json
import tempfile
from google.cloud import storage
from google.oauth2 import service_account

@api_view(['GET'])
def test_gcs_connection(request):
    """Test GCS connection and credentials"""
    
    result = {
        'status': 'testing',
        'credentials_available': False,
        'bucket_accessible': False,
        'upload_test': False,
        'objects_in_bucket': 0,
        'errors': []
    }
    
    try:
        # Check if credentials are available
        credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
        if not credentials_json:
            result['errors'].append('GOOGLE_APPLICATION_CREDENTIALS_JSON not found in environment')
            return JsonResponse(result)
        
        result['credentials_available'] = True
        
        # Parse credentials
        credentials_info = json.loads(credentials_json)
        project_id = credentials_info.get('project_id')
        
        # Create temporary credential file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_file:
            json.dump(credentials_info, temp_file)
            temp_file.flush()
            temp_cred_path = temp_file.name
        
        # Initialize client
        credentials = service_account.Credentials.from_service_account_file(temp_cred_path)
        client = storage.Client(credentials=credentials, project=project_id)
        
        bucket_name = 'storage-bucket-fortexpress'
        bucket = client.bucket(bucket_name)
        
        # Test bucket access
        if bucket.exists():
            result['bucket_accessible'] = True
            
            # Count objects in bucket
            blobs = list(bucket.list_blobs(max_results=100))
            result['objects_in_bucket'] = len(blobs)
            result['object_names'] = [blob.name for blob in blobs[:10]]  # First 10 objects
            
            # Test upload
            try:
                test_content = b"Test file content for GCS upload"
                blob_name = "test_uploads/connection_test.txt"
                
                blob = bucket.blob(blob_name)
                blob.upload_from_string(test_content, content_type='text/plain')
                
                # Try to make it public
                try:
                    blob.acl.all().grant_read()
                    blob.acl.save()
                except Exception as acl_error:
                    result['errors'].append(f'ACL error: {str(acl_error)}')
                
                result['upload_test'] = True
                result['test_file_url'] = f"https://storage.googleapis.com/{bucket_name}/{blob_name}"
                
            except Exception as upload_error:
                result['errors'].append(f'Upload error: {str(upload_error)}')
        else:
            result['errors'].append(f'Bucket {bucket_name} does not exist or is not accessible')
        
        # Clean up temp file
        os.unlink(temp_cred_path)
        
        result['status'] = 'completed'
        
    except Exception as e:
        result['errors'].append(f'General error: {str(e)}')
        result['status'] = 'failed'
    
    return JsonResponse(result)
