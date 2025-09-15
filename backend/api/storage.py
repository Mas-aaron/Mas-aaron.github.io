from storages.backends.gcloud import GoogleCloudStorage
from django.conf import settings

class PublicGoogleCloudStorage(GoogleCloudStorage):
    """
    Custom Google Cloud Storage backend that ensures public URLs
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.default_acl = 'publicRead'
        self.querystring_auth = False
    
    def url(self, name):
        """
        Return a public URL for the file
        """
        return f"https://storage.googleapis.com/{settings.GS_BUCKET_NAME}/{name}"
