from storages.backends.gcloud import GoogleCloudStorage
from django.conf import settings
import os

class PublicGoogleCloudStorage(GoogleCloudStorage):
    """
    Custom Google Cloud Storage backend that ensures public URLs
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.default_acl = 'publicRead'
        self.querystring_auth = False
        self.bucket_name = getattr(settings, 'GS_BUCKET_NAME', 'storage-bucket-fortexpress')
    
    def url(self, name):
        """
        Return a public URL for the file
        """
        if not name:
            return None
        # Ensure we always return a GCS URL, never a local media URL
        return f"https://storage.googleapis.com/{self.bucket_name}/{name}"
    
    def _save(self, name, content):
        """
        Override save to upload file and attempt to make it public
        """
        print(f"🔄 Starting GCS upload for: {name}")
        print(f"🔄 Bucket name: {self.bucket_name}")
        print(f"🔄 Content size: {content.size if hasattr(content, 'size') else 'unknown'}")
        
        try:
            # Save the file first
            blob_name = super()._save(name, content)
            print(f"✅ File uploaded to GCS: {blob_name}")
            print(f"✅ Full GCS path: gs://{self.bucket_name}/{blob_name}")
            
            # Try to make the individual object public
            try:
                blob = self.bucket.blob(blob_name)
                blob.acl.all().grant_read()
                blob.acl.save()
                print(f"✅ Made object public: {blob_name}")
            except Exception as acl_error:
                print(f"⚠️ Could not set object ACL (bucket permissions should handle this): {acl_error}")
            
            return blob_name
            
        except Exception as e:
            print(f"❌ Error uploading to GCS: {e}")
            import traceback
            print(f"❌ Full traceback: {traceback.format_exc()}")
            # Re-raise the exception so Django knows the upload failed
            raise
