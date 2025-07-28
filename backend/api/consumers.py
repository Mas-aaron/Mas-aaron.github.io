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
        print(f"[WS] Connection attempt for order {self.order_id} by user {user}")
        print(f"[WS] Scope: {self.scope}")
        # Temporarily allow unauthenticated connections for testing
        # if not user.is_authenticated:
        #     await self.close()
        #     print(f"[WS] Reject unauthenticated connection for order {self.order_id}")
        #     return
        # TODO: Optionally restrict to only customer/rider assigned to this order
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        print(f"[WS] {user} connected to {self.room_group_name}")
        print(f"[WS] Channel name: {self.channel_name}")
        await self.accept()
        print(f"[WS] Connection accepted for order {self.order_id}")

    async def disconnect(self, close_code):
        print(f"[WS] Disconnecting from {self.room_group_name} with close code {close_code}")
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
        # If we received a location, broadcast it.
        if lat is not None and lon is not None:
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'location.broadcast',
                    'lat': lat,
                    'lng': lon,
                }
            )

    async def tracking_message(self, event):
        message = event['message']

        await self.send(text_data=json.dumps({
            'message': message
        }))

    async def location_broadcast(self, event):
        # This method is called when a message with type 'location.broadcast' is sent to the group
        print(f"[WS] Broadcasting location to {self.room_group_name}: lat={event['lat']}, lng={event['lng']}")
        message_data = {
            'message': {
                'latitude': event['lat'],
                'longitude': event['lng']
            }
        }
        print(f"[WS] Sending message to client: {message_data}")
        try:
            await self.send(text_data=json.dumps(message_data))
            print(f"[WS] Successfully sent message to client for {self.room_group_name}")
        except Exception as e:
            print(f"[WS] Error sending message to client for {self.room_group_name}: {e}")
