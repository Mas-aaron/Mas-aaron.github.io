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
        Override save to ensure proper ACL is set
        """
        # Save the file first
        blob_name = super()._save(name, content)
        
        try:
            # Get the blob and make it public using ACL
            blob = self.bucket.blob(blob_name)
            
            # Try different methods to make the blob public
            try:
                # Method 1: Set ACL directly
                blob.acl.all().grant_read()
                blob.acl.save()
                print(f"✅ Made blob public via ACL: {blob_name}")
            except Exception as e1:
                try:
                    # Method 2: Use make_public
                    blob.make_public()
                    print(f"✅ Made blob public via make_public: {blob_name}")
                except Exception as e2:
                    print(f"⚠️ Could not make blob public: ACL={e1}, make_public={e2}")
                    
        except Exception as e:
            print(f"⚠️ Error accessing blob for public access: {e}")
        
        return blob_name
