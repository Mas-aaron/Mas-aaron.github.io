import json
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from asgiref.sync import sync_to_async
from django.contrib.auth.models import Group
from .models import RiderProfile, Order, Restaurant
from .serializers import OrderSerializer, RiderNotificationOrderSerializer, RestaurantOrderSerializer

# This helper function is required by the TrackingConsumer
@database_sync_to_async
def update_rider_location(user, lat, lon):
    try:
        profile, created = RiderProfile.objects.get_or_create(user=user)
        profile.latitude = lat
        profile.longitude = lon
        profile.save()
    except Exception as e:
        print(f"Error updating rider location: {e}")

# This is the corrected consumer for rider notifications
class RiderConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        is_rider = await self.is_user_in_rider_group(self.user)
        
        if self.user.is_authenticated and is_rider:
            self.room_group_name = 'riders_available'
            await self.channel_layer.group_add(self.room_group_name, self.channel_name)
            await self.accept()
            print(f"Rider {self.user.username} connected and added to 'riders_available' group.")
        else:
            print(f"Connection rejected for user {self.user.username} (not authenticated or not a rider).")
            await self.close()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
            print(f"Rider {self.user.username} disconnected.")

    async def receive(self, text_data):
        # This consumer is currently for notifications only.
        pass

    async def new_order_message(self, event):
        order_data = event['order']
        await self.send(text_data=json.dumps({
            'type': 'new_order',
            'order': order_data
        }))
        print(f"Sent new order notification {order_data.get('id')} to rider {self.user.username}.")

    @sync_to_async
    def is_user_in_rider_group(self, user):
        try:
            rider_group = Group.objects.get(name='Rider')
            return rider_group in user.groups.all()
        except Group.DoesNotExist:
            return False

# This is the restored consumer for order tracking
class TrackingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.order_id = self.scope['url_route']['kwargs']['order_id']
        self.room_group_name = f'track_{self.order_id}'
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()
        print(f"User connected to tracking for order {self.order_id}")

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
        print(f"User disconnected from tracking for order {self.order_id}")

    async def receive(self, text_data):
        data = json.loads(text_data)
        message_type = data.get('type')

        if message_type == 'rider_location_update':
            await update_rider_location(self.scope['user'], data['latitude'], data['longitude'])
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'location.broadcast',
                    'latitude': data['latitude'],
                    'longitude': data['longitude'],
                }
            )

    async def location_broadcast(self, event):
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'latitude': event['latitude'],
            'longitude': event['longitude']
        }))

# This is the new consumer for the restaurant dashboard
class RestaurantConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        if not self.user.is_authenticated:
            await self.close()
            return

        self.restaurant = await self.get_user_restaurant(self.user)
        if self.restaurant:
            self.room_group_name = f'restaurant_{self.restaurant.id}'
            await self.channel_layer.group_add(self.room_group_name, self.channel_name)
            await self.accept()
            print(f"Restaurant user {self.user.username} for restaurant {self.restaurant.id} connected.")
        else:
            await self.close()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        # This message is no longer used. The initial order list is fetched via REST.
        # The client still sends this message, so we just ignore it.
        pass

    async def new_order(self, event):
        order_data = json.loads(event['order'])
        await self.send(text_data=json.dumps({
            'type': 'new_orders',
            'orders': [order_data]
        }))

    async def order_status_update(self, event):
        # This handles the 'order.status.update' type message
        await self.send(text_data=json.dumps({
            'type': 'order_updates',  # Send a consistent type to the client
            'orders': [event['order']]
        }))

    async def order_update(self, event):
        await self.send(text_data=json.dumps({
            'type': 'order_updates',
            'orders': [event['order']]
        }))

    @database_sync_to_async
    def get_user_restaurant(self, user):
        try:
            return Restaurant.objects.get(owner=user)
        except Restaurant.DoesNotExist:
            return None

    @database_sync_to_async
    def get_initial_orders(self):
        orders = Order.objects.filter(restaurant=self.restaurant, status__in=['pending', 'preparing'])
        serializer = OrderSerializer(orders, many=True)
        return serializer.data


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        if not self.user.is_authenticated:
            await self.close()
            return

        self.room_group_name = f'user_{self.user.id}_notifications'
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()
        print(f"User {self.user.username} connected to notifications channel.")

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
            print(f"User {self.user.username} disconnected from notifications channel.")

    async def receive(self, text_data):
        # This consumer is for broadcasting notifications from the server,
        # so we don't expect to receive messages from clients.
        pass

    async def send_notification(self, event):
        message = event['message']
        await self.send(text_data=json.dumps(message))
        print(f"Sent notification to user {self.user.username}: {message}")