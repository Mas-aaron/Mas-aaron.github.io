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
        # Set the ACL to public-read for each uploaded file
        blob_name = super()._save(name, content)
        
        try:
            # Get the blob and make it public
            blob = self.bucket.blob(blob_name)
            blob.make_public()
        except Exception as e:
            print(f"Warning: Could not make blob public: {e}")
        
        return blob_name
