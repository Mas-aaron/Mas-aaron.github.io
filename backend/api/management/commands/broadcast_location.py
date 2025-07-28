import asyncio
import json
import os
import time
from decimal import Decimal

import googlemaps
from channels.layers import get_channel_layer
from django.core.management.base import BaseCommand
from dotenv import load_dotenv

from api.models import Order


class Command(BaseCommand):
    help = 'Broadcasts simulated location updates for a given order.'

    def add_arguments(self, parser):
        parser.add_argument('order_id', type=int, help='The ID of the order to track.')

    def handle(self, *args, **options):
        load_dotenv()
        gmaps_key = os.getenv("GOOGLE_MAPS_API_KEY")
        if not gmaps_key:
            self.stderr.write(self.style.ERROR('GOOGLE_MAPS_API_KEY not found in .env file.'))
            return
        gmaps = googlemaps.Client(key=gmaps_key)
        order_id = options['order_id']
        self.stdout.write(f'Starting location broadcast for order {order_id}...')

        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            self.stderr.write(self.style.ERROR(f'Order {order_id} not found.'))
            return

        if not all([order.restaurant_lat, order.restaurant_lng, order.customer_lat, order.customer_lng]):
            self.stderr.write(self.style.ERROR(f'Order {order_id} is missing location data.'))
            return

        channel_layer = get_channel_layer()
        if channel_layer is None:
            self.stderr.write(self.style.ERROR('Cannot get channel layer. Is Redis running?'))
            return

        group_name = f'track_{order_id}'

        start_lat, start_lng = order.restaurant_lat, order.restaurant_lng
        end_lat, end_lng = order.customer_lat, order.customer_lng

        self.stdout.write(f'Broadcasting to group: {group_name}')
        self.stdout.write(f'Route from ({start_lat}, {start_lng}) to ({end_lat}, {end_lng})')
        self.stdout.write('Press Ctrl+C to stop.')

        # Get directions from Google Maps
        try:
            directions_result = gmaps.directions((start_lat, start_lng),
                                                 (end_lat, end_lng),
                                                 mode="driving")
            if not directions_result:
                self.stderr.write(self.style.ERROR('Could not get directions from Google Maps.'))
                return

            # Decode the polyline to get the points on the route
            polyline = directions_result[0]['overview_polyline']['points']
            route_points = googlemaps.convert.decode_polyline(polyline)

        except Exception as e:
            self.stderr.write(self.style.ERROR(f'Error fetching directions from Google: {e}'))
            return

        num_steps = len(route_points)

        try:
            # Get or create event loop for asyncio operations
            try:
                loop = asyncio.get_event_loop()
            except RuntimeError:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
            for i, point in enumerate(route_points):
                current_lat = point['lat']
                current_lng = point['lng']

                message = {
                    'type': 'location.broadcast',
                    'lat': float(current_lat),
                    'lng': float(current_lng),
                }

                self.stdout.write(f'  Sending update {i+1}/{num_steps+1}: ({current_lat:.6f}, {current_lng:.6f})')
                try:
                    loop.run_until_complete(channel_layer.group_send(
                        group_name,
                        message
                    ))
                    self.stdout.write(f'  Successfully sent update {i+1}/{num_steps+1}')
                except Exception as e:
                    self.stderr.write(self.style.ERROR(f'  Failed to send update {i+1}/{num_steps+1}: {e}'))

                time.sleep(2)

            self.stdout.write(self.style.SUCCESS(f'Finished broadcasting for order {order_id}.'))

        except KeyboardInterrupt:
            self.stdout.write(self.style.WARNING('\nBroadcast stopped by user.'))
