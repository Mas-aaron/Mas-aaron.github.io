import os
from django.http import FileResponse, Http404
from django.conf import settings
from django.utils.deprecation import MiddlewareMixin


class MediaFileMiddleware(MiddlewareMixin):
    """
    Middleware to serve media files in production when WhiteNoise can't handle them.
    This is needed because WhiteNoise is designed for static files, not user uploads.
    """
    
    def process_request(self, request):
        if request.path.startswith(settings.MEDIA_URL):
            # Remove the MEDIA_URL prefix to get the relative file path
            relative_path = request.path[len(settings.MEDIA_URL):]
            file_path = os.path.join(settings.MEDIA_ROOT, relative_path)
            
            if os.path.exists(file_path) and os.path.isfile(file_path):
                response = FileResponse(open(file_path, 'rb'))
                # Add CORS headers for media files
                response['Access-Control-Allow-Origin'] = '*'
                response['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
                response['Access-Control-Allow-Headers'] = 'Content-Type'
                return response
            else:
                raise Http404("Media file not found")
        
        return None
