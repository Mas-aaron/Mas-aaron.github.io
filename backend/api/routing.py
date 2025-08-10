from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/rider/available/$', consumers.RiderConsumer.as_asgi()),
    re_path(r'ws/tracking/(?P<order_id>\d+)/$', consumers.TrackingConsumer.as_asgi()),
    re_path(r'ws/restaurant/orders/$', consumers.RestaurantConsumer.as_asgi()),
    re_path(r'ws/notifications/$', consumers.NotificationConsumer.as_asgi()),
]
