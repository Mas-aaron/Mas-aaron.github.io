import json
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from .models import Restaurant
from .serializers import RestaurantOrderSerializer

class RestaurantConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.user = self.scope['user']

        # The TokenAuthMiddleware already attaches the restaurant_profile to the user.
        # We can access it directly here.
        restaurant_profile = getattr(self.user, 'restaurant_profile', None)

        if restaurant_profile is None:
            # If no profile is found, close the connection.
            await self.close()
        else:
            # If a profile is found, proceed with setting up the WebSocket connection.
            self.restaurant_id = restaurant_profile.id
            self.room_group_name = f'restaurant_{self.restaurant_id}'

            await self.channel_layer.group_add(
                self.room_group_name,
                self.channel_name
            )
            await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    async def new_order(self, event):
        order_data = event['order']
        await self.send(text_data=json.dumps({
            'type': 'new_order',
            'order': order_data
        }))
