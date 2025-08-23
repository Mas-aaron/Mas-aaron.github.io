from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.contrib.auth.decorators import login_required
from django.utils.decorators import method_decorator
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import math
import json
import logging

from .models import Order, OrderActivity

logger = logging.getLogger(__name__)
from .notifications import send_push_notification


class RiderArrivalView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, order_id):
        """Handle rider arrival notification"""
        try:
            logger.info(f"RiderArrivalView POST request for order_id: {order_id}, user: {request.user.id}")
            logger.info(f"Request data: {request.data}")

            if not hasattr(request.user, 'rider_profile'):
                logger.warning(f"User {request.user.id} attempted to access rider view without a rider profile.")
                return Response({'error': 'User does not have a rider profile.'}, status=status.HTTP_403_FORBIDDEN)

            order = Order.objects.get(id=order_id, rider=request.user.rider_profile)
            
            # Get rider's current location
            rider_lat = float(request.data.get('latitude'))
            rider_lng = float(request.data.get('longitude'))
            
            # Check if rider is actually near customer location
            customer_lat = float(order.customer_lat) if order.customer_lat else 0.0
            customer_lng = float(order.customer_lng) if order.customer_lng else 0.0

            logger.info(f"Calculating distance: rider=({rider_lat}, {rider_lng}), customer=({customer_lat}, {customer_lng})")

            distance = self.calculate_distance(
                rider_lat, rider_lng,
                customer_lat,
                customer_lng
            )

            logger.info(f"Calculated distance: {distance} meters")
            
            # DEBUG: Larger radius for testing (change back to 200 in production)
            if distance > 1000:
                return Response(
                    {
                        'error': 'You are not close enough to the customer location',
                        'distance': distance,
                        'required_distance': 1000
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Update order status
            order.status = 'Rider Arrived'
            order.save()
            
            # Send notification to customer
            self.send_arrival_notification(order, rider_lat, rider_lng)
            
            # Create activity log
            OrderActivity.objects.create(
                order=order,
                activity_type='rider_arrived',
                description=f'Rider arrived at customer location',
                created_at=timezone.now()
            )
            
            return Response({
                'success': True,
                'message': 'Customer notified of your arrival',
                'distance': distance,
                'arrival_time': timezone.now().isoformat()
            })
            
        except Order.DoesNotExist:
            return Response(
                {'error': 'Order not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except (ValueError, TypeError) as e:
            return Response(
                {'error': f'Invalid location data: {str(e)}'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Unexpected error in RiderArrivalView: {e}", exc_info=True)
            return Response(
                {'error': f'Unexpected error: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def calculate_distance(self, lat1, lng1, lat2, lng2):
        """Calculate distance between two points using Haversine formula"""
        if not all([lat1, lng1, lat2, lng2]):
            return float('inf')  # Return large distance if coordinates missing
            
        earth_radius = 6371000  # meters
        
        d_lat = math.radians(lat2 - lat1)
        d_lng = math.radians(lng2 - lng1)
        
        a = (math.sin(d_lat/2) * math.sin(d_lat/2) +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(d_lng/2) * math.sin(d_lng/2))
        
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        
        return earth_radius * c

    def send_arrival_notification(self, order, rider_lat, rider_lng):
        """Send arrival notification to customer via push notification and WebSocket"""
        logger.info(f"Attempting to send arrival notification for order {order.id}")
        try:
            # Send push notification to customer
            rider_name = f"{order.rider.user.first_name} {order.rider.user.last_name}".strip()
            if not rider_name:
                rider_name = order.rider.user.username
            
            title = '🚗 Your rider has arrived!'
            body = f'{rider_name} is waiting at your location with your order #{order.id}'
            
            logger.info(f"Calling send_push_notification for user {order.user.id}")
            send_push_notification(
                user=order.user,
                title=title,
                body=body,
                data={
                    'type': 'rider_arrival',
                    'order_id': str(order.id),
                    'rider_name': rider_name,
                    'rider_location': {
                        'latitude': rider_lat,
                        'longitude': rider_lng
                    },
                    'timestamp': timezone.now().isoformat()
                }
            )
            logger.info(f"Successfully sent push notification for order {order.id}")
            
            # Send via WebSocket for real-time updates
            logger.info("Getting channel layer for WebSocket notification.")
            channel_layer = get_channel_layer()
            if channel_layer:
                logger.info(f"Sending WebSocket notification to group customer_{order.user.id}")
                async_to_sync(channel_layer.group_send)(
                    f'customer_{order.user.id}',
                    {
                        'type': 'rider_arrival_notification',
                        'order_id': order.id,
                        'rider_name': rider_name,
                        'rider_location': {
                            'latitude': rider_lat,
                            'longitude': rider_lng
                        },
                        'timestamp': timezone.now().isoformat(),
                        'message': 'Rider has arrived at your location'
                    }
                )
                logger.info(f"Successfully sent WebSocket notification for order {order.id}")
            else:
                logger.warning("Channel layer not available. Skipping WebSocket notification.")
                
        except Exception as e:
            logger.error(f'Failed to send arrival notification for order {order.id}: {e}', exc_info=True)


class RiderLocationUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, order_id):
        """Update rider location and check for proximity"""
        try:
            logger.info(f"RiderLocationUpdateView POST request for order_id: {order_id}, user: {request.user.id}")
            logger.info(f"Request data: {request.data}")

            if not hasattr(request.user, 'rider_profile'):
                logger.warning(f"User {request.user.id} attempted to access rider view without a rider profile.")
                return Response({'error': 'User does not have a rider profile.'}, status=status.HTTP_403_FORBIDDEN)

            order = Order.objects.get(id=order_id, rider=request.user.rider_profile)
            
            rider_lat = float(request.data.get('latitude'))
            rider_lng = float(request.data.get('longitude'))
            
            # Calculate distance to customer
            customer_lat = float(order.customer_lat) if order.customer_lat else 0.0
            customer_lng = float(order.customer_lng) if order.customer_lng else 0.0
            
            distance = RiderArrivalView().calculate_distance(
                rider_lat, rider_lng, customer_lat, customer_lng
            )
            
            # Send location update via WebSocket
            channel_layer = get_channel_layer()
            if channel_layer:
                async_to_sync(channel_layer.group_send)(
                    f'order_tracking_{order.id}',
                    {
                        'type': 'rider_location_update',
                        'rider_location': {
                            'latitude': rider_lat,
                            'longitude': rider_lng
                        },
                        'distance_to_customer': distance,
                        'timestamp': timezone.now().isoformat()
                    }
                )
            
            # Check if approaching (500m) and send notification
            if 100 < distance <= 500 and order.status != 'Rider Arrived':
                self.send_approaching_notification(order, distance)
            
            return Response({
                'success': True,
                'distance_to_customer': distance,
                'approaching': distance <= 500,
                'arrived': distance <= 100
            })
            
        except Order.DoesNotExist:
            return Response(
                {'error': 'Order not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Unexpected error in RiderLocationUpdateView: {e}", exc_info=True)
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def send_approaching_notification(self, order, distance):
        """Send approaching notification to customer"""
        try:
            rider_name = f"{order.rider.user.first_name} {order.rider.user.last_name}".strip()
            if not rider_name:
                rider_name = order.rider.user.username
                
            # Estimate arrival time based on distance (assuming 5 km/h walking speed)
            estimated_minutes = max(1, int(distance / 83.33))  # 83.33 m/min = 5 km/h
            
            title = '📍 Rider is approaching'
            body = f'{rider_name} is about {estimated_minutes} minute(s) away with your order'
            
            send_push_notification(
                user=order.user,
                title=title,
                body=body,
                data={
                    'type': 'rider_approaching',
                    'order_id': str(order.id),
                    'rider_name': rider_name,
                    'estimated_arrival': estimated_minutes,
                    'distance': distance
                }
            )
            
        except Exception as e:
            print(f"Error sending approaching notification: {e}")
