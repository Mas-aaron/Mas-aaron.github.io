import os
from django.http import FileResponse, Http404, HttpResponseRedirect
from django.conf import settings
from django.utils.deprecation import MiddlewareMixin
from django.core.files.storage import default_storage


class MediaFileMiddleware(MiddlewareMixin):
    """
    Middleware to serve media files in production when WhiteNoise can't handle them.
    This is needed because WhiteNoise is designed for static files, not user uploads.
    When using Supabase storage, redirect to the actual Supabase URL.
    """
    
    def process_request(self, request):
        if request.path.startswith(settings.MEDIA_URL):
            # Remove the MEDIA_URL prefix to get the relative file path
            relative_path = request.path[len(settings.MEDIA_URL):]
            
            # Check if we're using Supabase storage
            if hasattr(default_storage, 'client') and default_storage.client:
                # Using Supabase storage - redirect to the actual Supabase URL
                try:
                    supabase_url = default_storage.url(relative_path)
                    if supabase_url and supabase_url != request.path:
                        return HttpResponseRedirect(supabase_url)
                except Exception:
                    pass
            
            # Fallback to local file serving
            if hasattr(settings, 'MEDIA_ROOT'):
                file_path = os.path.join(settings.MEDIA_ROOT, relative_path)
                
                if os.path.exists(file_path) and os.path.isfile(file_path):
                    response = FileResponse(open(file_path, 'rb'))
                    # Add CORS headers for media files
                    response['Access-Control-Allow-Origin'] = '*'
                    response['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
                    response['Access-Control-Allow-Headers'] = 'Content-Type'
                    return response
            
            # File not found locally and no Supabase redirect available
            raise Http404("Media file not found")
        
        return None
