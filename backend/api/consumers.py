import json
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from .models import RiderProfile

@database_sync_to_async
def update_rider_location(user, lat, lon):
    try:
        profile, created = RiderProfile.objects.get_or_create(user=user)
        profile.latitude = lat
        profile.longitude = lon
        profile.save()
    except Exception as e:
        # Handle exceptions, e.g., logging
        print(f"Error updating rider location: {e}")

class TrackingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.order_id = self.scope['url_route']['kwargs']['order_id']
        self.room_group_name = f'track_{self.order_id}'
        user = self.scope['user']
        if not user.is_authenticated:
            await self.close()
            print(f"[WS] Reject unauthenticated connection for order {self.order_id}")
            return
        # TODO: Optionally restrict to only customer/rider assigned to this order
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        print(f"[WS] {user} connected to {self.room_group_name}")
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        print(f"[WS] Disconnected from {self.room_group_name}")

    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json.get('message', text_data_json)
        user = self.scope['user']
        try:
            # Only allow riders to send location
            lat = message.get('latitude')
            lon = message.get('longitude')
            if lat is not None and lon is not None:
                # Optionally: check user is assigned rider for this order
                await update_rider_location(user, lat, lon)
                print(f"[WS] {user} updated location for order {self.order_id}: {lat}, {lon}")
            # If status update, also relay
            status = message.get('status')
            if status is not None:
                print(f"[WS] {user} updated status for order {self.order_id}: {status}")
        except Exception as e:
            print(f"[WS ERROR] {user} failed to process message: {e}")
        # Broadcast message to group
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'tracking_message',
                'message': message
            }
        )

    async def tracking_message(self, event):
        message = event['message']

        await self.send(text_data=json.dumps({
            'message': message
        }))
