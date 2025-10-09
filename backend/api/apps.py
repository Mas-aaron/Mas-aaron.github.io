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
                # Try multiple service account key file paths
                service_account_paths = [
                    os.path.join(settings.BASE_DIR, 'serviceAccountKey.json'),
                    os.path.join(settings.BASE_DIR, 'firebase-service-account.json'),
                    os.path.join(settings.BASE_DIR, 'service-account-key.json')
                ]
                
                initialized = False
                for service_account_path in service_account_paths:
                    if os.path.exists(service_account_path):
                        try:
                            cred = credentials.Certificate(service_account_path)
                            firebase_admin.initialize_app(cred)
                            logger.info(f"Firebase Admin SDK initialized with service account key: {os.path.basename(service_account_path)}")
                            initialized = True
                            break
                        except Exception as key_error:
                            logger.warning(f"Failed to initialize with {service_account_path}: {key_error}")
                            continue
                
                if not initialized:
                    # Fallback to Application Default Credentials
                    # This works if GOOGLE_APPLICATION_CREDENTIALS env var is set
                    # or if running on Google Cloud with default service account
                    try:
                        firebase_admin.initialize_app()
                        logger.info("Firebase Admin SDK initialized with default credentials.")
                        initialized = True
                    except Exception as fallback_error:
                        logger.warning(f"Could not initialize Firebase with default credentials: {fallback_error}")
                        
                if not initialized:
                    logger.warning("Push notifications will be disabled. To enable:")
                    logger.warning("1. Download service account key from Firebase Console")
                    logger.warning("2. Save it as 'serviceAccountKey.json' in the backend directory")
                    logger.warning("3. Or set GOOGLE_APPLICATION_CREDENTIALS environment variable")
                        
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin SDK via ApiConfig: {e}", exc_info=True)
                logger.warning("Push notifications will be disabled.")
