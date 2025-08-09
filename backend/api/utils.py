from firebase_admin import messaging
from .models import Device

def send_push_notification(user, title, body, data=None, image_url=None):
    """
    Sends a push notification to all registered devices for a given user.
    Handles multiple devices and aggregates success/failure.
    Includes support for rich notifications with images.
    """
    devices = Device.objects.filter(user=user, is_active=True)
    if not devices.exists():
        print(f"No active devices found for user {user.username}")
        return False

    success_count = 0
    for device in devices:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                    image=image_url, # FCM will handle the image if the URL is valid
                ),
                token=device.token,
                data=data or {},
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(
                        image=image_url,
                    )
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            mutable_content=True,
                        )
                    ),
                    fcm_options=messaging.APNSFCMOptions(
                        image=image_url,
                    )
                )
            )
            messaging.send(message)
            success_count += 1
        except Exception as e:
            print(f"Failed to send notification to device {device.token}: {e}")
    
    return success_count > 0
