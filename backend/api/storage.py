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
    with proper fallback to local storage
    """
    
    def __init__(self, *args, **kwargs):
        print(f"🔧 Initializing PublicGoogleCloudStorage (storages available: {STORAGES_AVAILABLE})")
        super().__init__(*args, **kwargs)
        
        self.bucket_name = getattr(settings, 'GS_BUCKET_NAME', 'storage-bucket-fortexpress')
        
        if STORAGES_AVAILABLE:
            self.default_acl = 'publicRead'
            self.querystring_auth = False
            self._init_bucket()
        
        print(f"✅ Storage initialized with bucket: {self.bucket_name}")
    
    def _init_bucket(self):
        """Initialize GCS bucket if not already done"""
        try:
            from google.cloud.storage import Client
            client = Client()
            self.bucket = client.bucket(self.bucket_name)
            print(f"✅ GCS bucket initialized: {self.bucket_name}")
        except Exception as e:
            print(f"❌ Failed to initialize GCS bucket: {e}")
            # Don't raise here to allow fallback behavior
    
    def url(self, name):
        """
        Override url method to return appropriate URLs based on storage availability
        """
        if not name:
            return None
        
        if STORAGES_AVAILABLE:
            try:
                # Return GCS URL when storages is available
                return f"https://storage.googleapis.com/{self.bucket_name}/{name}"
            except Exception:
                # Fallback if GCS URL construction fails
                pass
        
        # Fallback to local URL when storages is not available or GCS fails
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
                # Ensure bucket is initialized
                if not hasattr(self, 'bucket'):
                    self._init_bucket()
                
                # Call parent save method to upload to GCS
                blob_name = super()._save(name, content)
                print(f"✅ File uploaded to GCS: {blob_name}")
                
                # Try to make the object publicly readable
                try:
                    blob = self.bucket.blob(blob_name)
                    blob.make_public()
                    print(f"✅ Made object public: {blob_name}")
                except Exception as acl_error:
                    print(f"⚠️ Could not set object ACL: {acl_error}")
                
                return blob_name
                
            except Exception as e:
                print(f"❌ Error uploading to GCS: {e}")
                import traceback
                print(f"❌ Full traceback: {traceback.format_exc()}")
                # Fall through to local storage
                print("🔄 Falling back to local storage due to GCS error...")
        
        # Fallback to local storage when django-storages is not available or GCS fails
        print(f"⚠️ Using local storage for: {name}")
        return super()._save(name, content)