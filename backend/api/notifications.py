import firebase_admin
from firebase_admin import messaging
from firebase_admin.exceptions import FirebaseError
from django.conf import settings
import logging

from .models import Device

logger = logging.getLogger(__name__)

# Initialize Firebase app if not already done
if not firebase_admin._apps:
    # This part should ideally be in your settings or app config
    # For now, we ensure it's initialized before use.
    try:
        # Ensure you have GOOGLE_APPLICATION_CREDENTIALS set in your environment
        firebase_admin.initialize_app()
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")

def send_push_notification(user, title, body, data=None, image_url=None):
    """
    Send push notification to a user's devices
    Returns True if sent to at least one device, False otherwise
    """
    if not firebase_admin._apps:
        logger.error("Firebase Admin SDK not initialized. Cannot send push notification.")
        return False
        
    try:
        # Get active devices for user
        devices = Device.objects.filter(user=user, is_active=True)
        if not devices.exists():
            logger.warning(f"No active devices found for user {user.id}")
            return False

        success_count = 0
        failure_count = 0

        for device in devices:
            try:
                # Create message with device token
                # Create the base notification payload
                notification_payload = messaging.Notification(
                    title=title,
                    body=body,
                    image=image_url  # For Android/Web
                )

                # Create the full message for cross-platform rich notifications
                message = messaging.Message(
                    notification=notification_payload,
                    token=device.token,
                    data=data or {},
                    apns=messaging.APNSConfig(
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(
                                mutable_content=True,  # Required for iOS to display images
                                sound='default'
                            )
                        )
                    )
                )

                # Send message
                response = messaging.send(message)
                logger.info(f"Successfully sent message to device {device.id}: {response}")
                success_count += 1

            except FirebaseError as e:
                logger.error(f"Firebase error sending to device {device.id}: {str(e)}")
                failure_count += 1
                
                # Handle specific error cases safely
                if hasattr(e, 'code') and (e.code == 'messaging/registration-token-not-registered' or e.code == 'messaging/invalid-registration-token'):
                    device.is_active = False
                    device.save()
                    logger.warning(f"Deactivated invalid device token for user {user.id}: {device.token}")
                else:
                    logger.warning(f"Unhandled FirebaseError for device {device.id}. Error: {e}")

        logger.info(f"Notification results for user {user.id}: {success_count} successful, {failure_count} failed")
        return success_count > 0

    except Exception as e:
        logger.error(f"Unexpected error sending notification for user {user.id}: {str(e)}", exc_info=True)
        return False
