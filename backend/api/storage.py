try:
    from storages.backends.gcloud import GoogleCloudStorage
    STORAGES_AVAILABLE = True
except ImportError:
    # Fallback when django-storages is not available
    from django.core.files.storage import FileSystemStorage as GoogleCloudStorage
    STORAGES_AVAILABLE = False


from django.conf import settings
from django.core.files.storage import default_storage
import os


class PublicGoogleCloudStorage(GoogleCloudStorage):
    """
    Custom Google Cloud Storage backend that ensures public URLs
    """
    def __init__(self, *args, **kwargs):
        print(f"🔧 Initializing PublicGoogleCloudStorage (storages available: {STORAGES_AVAILABLE})")
        super().__init__(*args, **kwargs)
        if STORAGES_AVAILABLE:
            self.default_acl = 'publicRead'
            self.querystring_auth = False
        self.bucket_name = getattr(settings, 'GS_BUCKET_NAME', 'storage-bucket-fortexpress')
        print(f"✅ Storage initialized with bucket: {self.bucket_name}")
    
    def url(self, name):
        """
        Override url method to return appropriate URLs based on storage availability
        """
        if not name:
            return None
        
        if STORAGES_AVAILABLE and hasattr(self, 'bucket_name'):
            # Return GCS URL when storages is available
            return f"https://storage.googleapis.com/{self.bucket_name}/{name}"
        else:
            # Fallback to local URL when storages is not available
            return super().url(name)
    
    def _save(self, name, content):
        """
        Override save to handle both GCS and local storage based on availability
        """
        if STORAGES_AVAILABLE:
            print(f"🔄 Starting GCS upload for: {name}")
            print(f"🔄 Bucket name: {self.bucket_name}")
            print(f"🔄 Content size: {content.size if hasattr(content, 'size') else 'unknown'}")
            
            try:
                # Call parent save method to upload to GCS
                blob_name = super()._save(name, content)
                print(f"✅ File uploaded to GCS: {blob_name}")
                print(f"✅ Full GCS path: gs://{self.bucket_name}/{blob_name}")
                
                # Try to make the object publicly readable
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
                raise
        else:
            # Fallback to local storage when django-storages is not available
            print(f"⚠️ django-storages not available, saving locally: {name}")
            return super()._save(name, content)
