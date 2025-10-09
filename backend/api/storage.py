try:
    from supabase import create_client, Client
    SUPABASE_AVAILABLE = True
except ImportError:
    SUPABASE_AVAILABLE = False

from django.core.files.storage import Storage
from django.conf import settings
from django.core.files.base import ContentFile
from django.utils.deconstruct import deconstructible
from django.core.cache import cache
import os
import uuid
import mimetypes
from urllib.parse import urljoin


@deconstructible
class SupabaseStorage(Storage):
    """
    Custom Supabase Storage backend for Django
    """
    
    def __init__(self, *args, **kwargs):
        print(f"🔧 Initializing SupabaseStorage (supabase available: {SUPABASE_AVAILABLE})")
        super().__init__(*args, **kwargs)
        
        # Get Supabase configuration from settings
        self.supabase_url = getattr(settings, 'SUPABASE_URL', None)
        self.supabase_key = getattr(settings, 'SUPABASE_ANON_KEY', None)
        self.bucket_name = getattr(settings, 'SUPABASE_STORAGE_BUCKET', 'images')
        
        if SUPABASE_AVAILABLE and self.supabase_url and self.supabase_key:
            try:
                self.client: Client = create_client(self.supabase_url, self.supabase_key)
                print(f"✅ Supabase client initialized with bucket: {self.bucket_name}")
            except Exception as e:
                print(f"❌ Failed to initialize Supabase client: {e}")
                self.client = None
        else:
            print("⚠️ Supabase not available or not configured, using local storage fallback")
            self.client = None
    
    def _save(self, name, content):
        """
        Save file to Supabase Storage
        """
        if not self.client:
            # Fallback to local storage
            return self._save_local(name, content)
        
        try:
            # Generate unique filename to avoid conflicts
            file_extension = os.path.splitext(name)[1]
            unique_name = f"{uuid.uuid4()}{file_extension}"
            
            # Get content type
            content_type, _ = mimetypes.guess_type(name)
            if not content_type:
                content_type = 'application/octet-stream'
            
            print(f"🔄 Starting Supabase upload for: {unique_name}")
            print(f"🔄 Bucket name: {self.bucket_name}")
            print(f"🔄 Content type: {content_type}")
            
            # Read file content
            content.seek(0)
            file_data = content.read()
            
            # Upload to Supabase Storage
            response = self.client.storage.from_(self.bucket_name).upload(
                path=unique_name,
                file=file_data,
                file_options={
                    "content-type": content_type
                }
            )
            
            # If the upload call completes without raising an exception, it's successful.
            # The supabase-py library raises an exception for non-2xx responses.
            print(f"✅ File uploaded to Supabase: {unique_name}")
            return unique_name
                
        except Exception as e:
            print(f"❌ Error uploading to Supabase: {e}")
            import traceback
            print(f"❌ Full traceback: {traceback.format_exc()}")
            # Fall back to local storage
            print("🔄 Falling back to local storage due to Supabase error...")
            return self._save_local(name, content)
    
    def _save_local(self, name, content):
        """
        Fallback method to save file locally
        """
        from django.core.files.storage import FileSystemStorage
        local_storage = FileSystemStorage()
        print(f"⚠️ Using local storage for: {name}")
        return local_storage._save(name, content)
    
    def url(self, name):
        """
        Return the URL for accessing the file with optional caching to prevent excessive API calls
        """
        if not name:
            return None
        
        # Try to use cache if available, but don't fail if cache is unavailable
        cache_key = f"supabase_url_{self.bucket_name}_{name}"
        cached_url = None
        try:
            cached_url = cache.get(cache_key)
            if cached_url:
                return cached_url
        except Exception as cache_error:
            # Cache unavailable (Redis connection issues, etc.) - continue without caching
            # Only log this occasionally to avoid spam
            import time
            if not hasattr(self, '_last_cache_error_log') or time.time() - self._last_cache_error_log > 300:
                print(f"⚠️ Cache unavailable: {cache_error}")
                self._last_cache_error_log = time.time()
        
        if self.client and self.supabase_url:
            try:
                # Get public URL from Supabase
                response = self.client.storage.from_(self.bucket_name).get_public_url(name)
                if response:
                    # Clean up the URL to remove any trailing question marks
                    clean_url = response.split('?')[0]
                    
                    # Try to cache the URL, but don't fail if cache is unavailable
                    try:
                        cache.set(cache_key, clean_url, 3600)
                        # Only log occasionally to reduce log spam
                        try:
                            if not cache.get(f"logged_{cache_key}"):
                                print(f"✅ Generated and cached Supabase URL for: {name}")
                                cache.set(f"logged_{cache_key}", True, 300)  # Log once every 5 minutes
                        except Exception:
                            # If logging cache fails, just log normally (but less frequently)
                            import time
                            if not hasattr(self, '_last_log_time') or time.time() - self._last_log_time > 300:
                                print(f"✅ Generated Supabase URL for: {name}")
                                self._last_log_time = time.time()
                    except Exception as cache_set_error:
                        # Cache unavailable for writing - just log normally (but less frequently)
                        import time
                        if not hasattr(self, '_last_cache_set_error') or time.time() - self._last_cache_set_error > 300:
                            print(f"⚠️ Cache set failed: {cache_set_error}")
                            self._last_cache_set_error = time.time()
                        print(f"✅ Generated Supabase URL for: {name}")
                    
                    return clean_url
            except Exception as e:
                print(f"❌ Error getting Supabase URL: {e}")
        
        # Fallback to local URL
        from django.core.files.storage import FileSystemStorage
        local_storage = FileSystemStorage()
        return local_storage.url(name)
    
    def exists(self, name):
        """
        Check if file exists in Supabase Storage
        """
        if not self.client:
            from django.core.files.storage import FileSystemStorage
            local_storage = FileSystemStorage()
            return local_storage.exists(name)
        
        try:
            # List files to check if it exists
            response = self.client.storage.from_(self.bucket_name).list(
                path="",
                search=name
            )
            return len(response) > 0
        except Exception:
            return False
    
    def delete(self, name):
        """
        Delete file from Supabase Storage
        """
        if not self.client:
            from django.core.files.storage import FileSystemStorage
            local_storage = FileSystemStorage()
            return local_storage.delete(name)
        
        try:
            response = self.client.storage.from_(self.bucket_name).remove([name])
            return response.status_code == 200
        except Exception as e:
            print(f"❌ Error deleting from Supabase: {e}")
            return False
    
    def size(self, name):
        """
        Get file size
        """
        # For simplicity, return 0 if we can't determine size
        # In a production app, you might want to implement this properly
        return 0