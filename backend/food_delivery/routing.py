from django.urls import re_path
from api.consumers import TrackingConsumer

websocket_urlpatterns = [
    re_path(r'^ws/track/(?P<order_id>\w+)/$', TrackingConsumer.as_asgi()),
]
