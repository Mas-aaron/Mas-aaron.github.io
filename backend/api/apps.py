from django.apps import AppConfig
import firebase_admin
from firebase_admin import credentials
from django.conf import settings
import logging
import os

logger = logging.getLogger(__name__)

class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        # This method is called when Django starts
        if not firebase_admin._apps:
            try:
                # Try to use service account key file first
                service_account_path = os.path.join(settings.BASE_DIR, 'serviceAccountKey.json')
                
                if os.path.exists(service_account_path):
                    cred = credentials.Certificate(service_account_path)
                    firebase_admin.initialize_app(cred)
                    logger.info("Firebase Admin SDK initialized with service account key.")
                else:
                    # Fallback to Application Default Credentials
                    # This works if GOOGLE_APPLICATION_CREDENTIALS env var is set
                    # or if running on Google Cloud with default service account
                    try:
                        firebase_admin.initialize_app()
                        logger.info("Firebase Admin SDK initialized with default credentials.")
                    except Exception as fallback_error:
                        logger.warning(f"Could not initialize Firebase with default credentials: {fallback_error}")
                        logger.warning("Push notifications will be disabled. To enable:")
                        logger.warning("1. Download service account key from Firebase Console")
                        logger.warning("2. Save it as 'service-account-key.json' in the backend directory")
                        logger.warning("3. Or set GOOGLE_APPLICATION_CREDENTIALS environment variable")
                        
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK via ApiConfig: {e}", exc_info=True)
                logger.warning("Push notifications will be disabled.")
