import os

from django.core.asgi import get_asgi_application

# Set the DJANGO_SETTINGS_MODULE environment variable.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')

# Initialize the Django ASGI application early to ensure the settings are configured
# and the app registry is populated before any other imports happen.
django_asgi_app = get_asgi_application()

# Now, import the rest of the Channels components.
from channels.routing import ProtocolTypeRouter, URLRouter
import api.routing
from api.middleware import TokenAuthMiddleware

application = ProtocolTypeRouter({
    # Django's ASGI application to handle traditional HTTP requests.
    "http": django_asgi_app,

    # WebSocket handler.
    "websocket": TokenAuthMiddleware(
        URLRouter(
            api.routing.websocket_urlpatterns
        )
    ),
})
