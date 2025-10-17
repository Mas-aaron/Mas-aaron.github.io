import requests
from .notifications import send_push_notification, send_order_status_notification
from .models import NotificationTemplate
from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView
from django.conf import settings
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.db.models import Avg, F, FloatField, ExpressionWrapper, Sum, Count, Q
from django.db.models.functions import Radians, Power, Sin, Cos, Sqrt, ATan2, TruncMonth
from datetime import datetime, timedelta
from django.utils import timezone
from django.shortcuts import get_object_or_404
import logging
import json
from django.core.serializers.json import DjangoJSONEncoder

from rest_framework import viewsets, generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.generics import RetrieveAPIView
from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from django.contrib.auth.models import User
from django.utils import timezone
from django.http import JsonResponse
import os

@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """Simple health check endpoint for Railway deployment testing"""
    return Response({
        'status': 'healthy',
        'message': 'Railway backend is running',
        'timestamp': timezone.now().isoformat()
    })

@api_view(['GET'])
def test_gcs_connection(request):
    """Test GCS connection and credentials"""
    from django.conf import settings
    from django.core.files.storage import default_storage
    
    result = {
        'status': 'testing',
        'credentials_available': False,
        'default_file_storage': getattr(settings, 'DEFAULT_FILE_STORAGE', 'Not set'),
        'actual_storage_class': str(type(default_storage)),
        'media_url': getattr(settings, 'MEDIA_URL', 'Not set'),
        'gs_bucket_name': getattr(settings, 'GS_BUCKET_NAME', 'Not set'),
        'environment_vars': {},
        'errors': []
    }
    
    try:
        # Check environment variables
        env_vars_to_check = [
            'GOOGLE_APPLICATION_CREDENTIALS_JSON',
            'GS_BUCKET_NAME', 
            'GS_PROJECT_ID',
            'GOOGLE_APPLICATION_CREDENTIALS'
        ]
        
        for var in env_vars_to_check:
            value = os.getenv(var)
            if value:
                # Truncate long values for security
                if len(value) > 50:
                    result['environment_vars'][var] = f"{value[:50]}... (truncated)"
                else:
                    result['environment_vars'][var] = value
            else:
                result['environment_vars'][var] = 'Not set'
        
        # Check if credentials are available
        credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
        if credentials_json:
            result['credentials_available'] = True
            result['status'] = 'credentials_found'
        else:
            result['status'] = 'no_credentials'
        
        # Test if we can create a simple file
        try:
            from django.core.files.base import ContentFile
            test_file = ContentFile(b'test content')
            file_name = default_storage.save('test_file.txt', test_file)
            result['test_upload'] = f'Success: {file_name}'
            result['test_url'] = default_storage.url(file_name)
        except Exception as upload_error:
            result['test_upload'] = f'Failed: {str(upload_error)}'
        
    except Exception as e:
        result['errors'].append(f'General error: {str(e)}')
        result['status'] = 'failed'
    
    return JsonResponse(result)

@api_view(['POST'])
@permission_classes([IsAdminUser])
def configure_gcs_bucket(request):
    """Configure GCS bucket for public access - Admin only"""
    try:
        from django.core.management import call_command
        from io import StringIO
        
        # Capture command output
        output = StringIO()
        call_command('configure_gcs', stdout=output)
        
        return Response({
            'status': 'success',
            'message': 'GCS bucket configuration completed',
            'output': output.getvalue()
        })
    except Exception as e:
        return Response({
            'status': 'error',
            'message': f'Failed to configure GCS bucket: {str(e)}'
        }, status=500)

from django.contrib.auth.models import User
from django.contrib.auth import login, logout, authenticate
from django.utils import timezone

from geopy.distance import geodesic

from .permissions import IsCustomer, IsRestaurantOwner
from .models import (
    Bill,
    Restaurant, MenuCategory, MenuItem, ModifierGroup, Modifier, Cart, CartItem, 
    Order, OrderItem, Message, Notification, DietaryPreference, CustomerProfile, 
    UserAddress, Review, Device, RiderProfile, NotificationTemplate, OrderReview, RiderReview, PaymentPeriod, BankAccount, PaymentDispute, Payment
)
from .dispatch_service import find_and_assign_rider
from loyalty.services import LoyaltyService
from .serializers import (
    # Import ALL serializers to avoid missing import errors
    MenuItemBulkUploadSerializer, RestaurantProfileSerializer, RestaurantSerializer,
    UserSerializer, RestaurantSignUpSerializer, ModifierSerializer, ModifierGroupSerializer,
    MenuItemSerializer, MenuCategoryCRUDSerializer, MenuCategorySerializer,
    MenuCategoryListSerializer, CartItemSerializer, RestaurantOrderItemSerializer,
    RestaurantOrderSerializer, CartItemWriteSerializer, CartSerializer,
    OrderItemSerializer, OrderReviewSerializer, RiderPublicProfileSerializer,
    CustomerContactSerializer, OrderSerializer, RiderNotificationOrderSerializer,
    CustomerSerializer, RiderOrderSerializer, OrderUpdateStatusSerializer,
    NotificationSerializer, MessageSerializer, DeviceSerializer, RiderSignUpSerializer,
    DietaryPreferenceSerializer, UserAddressSerializer, CustomerProfileSerializer,
    RestaurantDashboardReviewSerializer, BillSerializer, PaymentSerializer,
    PaymentInitiateSerializer, CustomerSignUpSerializer, RestaurantReviewSerializer,
    RestaurantOrderReviewSerializer, RiderReviewSerializer, PaymentPeriodSerializer,
    OrderPaymentSerializer, BankAccountSerializer, PaymentDisputeSerializer,
    ReviewSerializer,  # Add the missing ReviewSerializer
)

logger = logging.getLogger(__name__)

# --- Device and Notification Views ---

class DeviceViewSet(viewsets.ModelViewSet):
    """Handles device registration for push notifications."""
    serializer_class = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Ensures users can only see their own devices."""
        return Device.objects.filter(user=self.request.user)

    def create(self, request, *args, **kwargs):
        """Handles device registration. Updates existing device or creates a new one."""
        registration_id = request.data.get('registration_id')
        device_type = request.data.get('type')

        if not registration_id or not device_type:
            return Response(
                {"error": "Both registration_id and type are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Use update_or_create for idempotent device registration.
            # Match the model fields: 'token' and 'device_type'.
            device, created = Device.objects.update_or_create(
                user=request.user, 
                token=registration_id,
                defaults={'device_type': device_type, 'is_active': True}
            )
        except Exception as e:
            # Log the error and return a graceful response
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Database error in device registration: {e}")
            return Response(
                {"error": "Device registration temporarily unavailable. Please try again."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        serializer = self.get_serializer(device)
        status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(serializer.data, status=status_code)

    @action(detail=False, methods=['post'])
    def unregister(self, request):
        """Unregisters a device by marking it as inactive."""
        registration_id = request.data.get('registration_id')
        if not registration_id:
            return Response({'error': 'Device registration_id not provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Match the model field 'token' for filtering.
        updated_count = Device.objects.filter(
            user=request.user, 
            token=registration_id
        ).update(is_active=False)

        if updated_count == 0:
            return Response({'error': 'Device not found for this user.'}, status=status.HTTP_404_NOT_FOUND)

        return Response(status=status.HTTP_204_NO_CONTENT)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_restaurant_device(request):
    """Register a device specifically for restaurant notifications"""
    try:
        fcm_token = request.data.get('fcm_token')
        device_type = request.data.get('device_type', 'restaurant')
        
        if not fcm_token:
            return Response(
                {'error': 'FCM token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if user is associated with a restaurant
        try:
            restaurant = Restaurant.objects.get(owner=request.user)
        except Restaurant.DoesNotExist:
            return Response(
                {'error': 'User is not associated with any restaurant'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Register or update device for restaurant notifications
        device, created = Device.objects.update_or_create(
            user=request.user,
            token=fcm_token,
            defaults={
                'device_type': device_type,
                'is_active': True
            }
        )
        
        logger.info(f"Restaurant device {'registered' if created else 'updated'} for user {request.user.id}, restaurant {restaurant.id}")
        
        return Response({
            'status': 'success',
            'message': f'Restaurant device {"registered" if created else "updated"} successfully',
            'restaurant_id': restaurant.id,
            'restaurant_name': restaurant.name
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error registering restaurant device: {e}")
        return Response(
            {'error': 'Failed to register restaurant device'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_rider_device(request):
    """Register a device specifically for rider notifications"""
    try:
        fcm_token = request.data.get('fcm_token')
        device_type = request.data.get('device_type', 'rider')
        
        if not fcm_token:
            return Response(
                {'error': 'FCM token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if user has a rider profile
        try:
            rider_profile = RiderProfile.objects.get(user=request.user)
        except RiderProfile.DoesNotExist:
            return Response(
                {'error': 'User is not registered as a rider'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Register or update device for rider notifications
        device, created = Device.objects.update_or_create(
            user=request.user,
            token=fcm_token,
            defaults={
                'device_type': device_type,
                'is_active': True
            }
        )
        
        logger.info(f"Rider device {'registered' if created else 'updated'} for user {request.user.id}")
        
        return Response({
            'status': 'success',
            'message': f'Rider device {"registered" if created else "updated"} successfully',
            'rider_id': rider_profile.id
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error registering rider device: {e}")
        return Response(
            {'error': 'Failed to register rider device'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def test_restaurant_notification(request):
    """Endpoint to test restaurant push notifications"""
    try:
        # Check if user is a restaurant owner
        try:
            restaurant = Restaurant.objects.get(owner=request.user)
        except Restaurant.DoesNotExist:
            return Response({
                'status': 'failed',
                'message': 'User is not a restaurant owner'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check for active restaurant devices
        active_devices = Device.objects.filter(
            user=request.user,
            is_active=True,
            device_type='restaurant'
        )
        
        if not active_devices.exists():
            return Response({
                'status': 'failed',
                'message': 'No active restaurant devices found. Please login to restaurant app.',
                'device_count': 0
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Send test notification
        notification_sent = send_push_notification(
            request.user,
            "🧪 Test Notification",
            f"Test notification for {restaurant.name} - System is working!",
            data={
                'type': 'test',
                'restaurant_id': str(restaurant.id),
                'timestamp': timezone.now().isoformat()
            }
        )
        
        return Response({
            'status': 'success' if notification_sent else 'failed',
            'message': f'Test notification {"sent" if notification_sent else "failed"} to {restaurant.name}',
            'device_count': active_devices.count(),
            'restaurant_name': restaurant.name
        })
        
    except Exception as e:
        logger.error(f"Error in test restaurant notification: {e}")
        return Response({
            'status': 'error',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def test_notification(request):
    """Endpoint to test push notifications"""
    try:
        # Verify user has registered devices
        active_devices = request.user.devices.filter(is_active=True)
        if not active_devices.exists():
            return Response({
                'status': 'failed',
                'message': 'User has no active devices registered',
                'device_count': 0
            }, status=status.HTTP_400_BAD_REQUEST)

        # Send test notification
        notification_sent_successfully = send_push_notification(
            request.user,
            "Test Notification",
            "This is a test notification from the server",
            {
                'type': 'test',
                'timestamp': str(timezone.now()),
                'user_id': str(request.user.id),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK' # Important for foreground taps
            }
        )

        if notification_sent_successfully:
            return Response({
                'status': 'success',
                'message': 'Test notification sent to at least one device.',
                'device_count': active_devices.count(),
            })
        else:
            return Response({
                'status': 'failed',
                'message': 'Failed to send notification to any devices. Check server logs for details.',
                'device_count': active_devices.count(),
            }, status=status.HTTP_400_BAD_REQUEST)

    except Exception as e:
        logger.error(f"Test notification failed: {str(e)}", exc_info=True)
        return Response({
            'status': 'error',
            'message': 'An internal server error occurred while sending the notification.',
            'error_details': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SendTemplateNotificationView(APIView):
    """
    An admin-only endpoint to send a notification to a user based on a pre-defined template.
    """
    permission_classes = [IsAdminUser]

    def post(self, request, *args, **kwargs):
        template_name = request.data.get('template_name')
        user_id = request.data.get('user_id')

        if not template_name or not user_id:
            return Response(
                {'error': 'template_name and user_id are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            template = NotificationTemplate.objects.get(name=template_name)
            user = User.objects.get(id=user_id)
        except NotificationTemplate.DoesNotExist:
            return Response(
                {'error': f'Template with name "{template_name}" not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        except User.DoesNotExist:
            return Response(
                {'error': f'User with id "{user_id}" not found.'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Prepare a simple data payload
        data_payload = {
            'template_name': template.name,
            'category': template.category,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK', # Standard for FCM
        }

        # Send the notification using our enhanced function
        success = send_push_notification(
            user=user,
            title=template.title,
            body=template.body,
            data=data_payload,
            image_url=template.image_url
        )

        if success:
            return Response(
                {'message': f'Successfully dispatched "{template.name}" notification for user {user.username}.'},
                status=status.HTTP_200_OK
            )
        else:
            return Response(
                {'error': 'Failed to send notification to any device. Check logs for details.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# --- Restaurant and Menu Views ---

class RestaurantViewSet(viewsets.ReadOnlyModelViewSet):
    """Provides a read-only API for listing approved restaurants, with optional proximity filtering."""
    serializer_class = RestaurantSerializer

    def get_queryset(self):
        queryset = Restaurant.objects.filter(is_approved=True).annotate(
            average_rating=Avg('reviews__rating')
        )
        lat = self.request.query_params.get('lat')
        lng = self.request.query_params.get('lng')

        if lat and lng:
            try:
                lat_f = float(lat)
                lng_f = float(lng)
                earth_radius_km = 6371.0
                dlat = Radians(F('latitude') - lat_f)
                dlon = Radians(F('longitude') - lng_f)
                a = Power(Sin(dlat / 2), 2) + Cos(Radians(lat_f)) * Cos(Radians(F('latitude'))) * Power(Sin(dlon / 2), 2)
                c = 2 * ATan2(Sqrt(a), Sqrt(1 - a))
                distance = ExpressionWrapper(earth_radius_km * c, output_field=FloatField())
                queryset = queryset.annotate(distance=distance).order_by('distance')
            except (ValueError, TypeError):
                pass
        return queryset

    def get_serializer_context(self):
        context = super().get_serializer_context()
        lat = self.request.query_params.get('lat')
        lng = self.request.query_params.get('lng')
        if lat and lng:
            try:
                context['user_location'] = (float(lat), float(lng))
            except (ValueError, TypeError):
                pass
        return context

class MenuItemListByRestaurantView(generics.ListAPIView):
    serializer_class = MenuItemSerializer

    def get_queryset(self):
        restaurant_pk = self.kwargs['restaurant_pk']
        queryset = MenuItem.objects.filter(category__restaurant_id=restaurant_pk)
        dietary_preferences = self.request.query_params.getlist('dietary_preferences')
        if dietary_preferences:
            for preference_id in dietary_preferences:
                queryset = queryset.filter(dietary_preferences=preference_id)
        return queryset.distinct()

# --- Cart and Order Views ---

class CartView(generics.RetrieveAPIView):
    serializer_class = CartSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        cart, _ = Cart.objects.get_or_create(user=self.request.user)
        return cart

class CartDetailView(RetrieveAPIView):
    """
    Retrieve the cart for the current user.
    Creates a cart if one doesn't exist.
    """
    serializer_class = CartSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        cart, created = Cart.objects.get_or_create(user=self.request.user)
        return cart


class AddToCartView(APIView):
    """
    A dedicated view to handle adding items to the cart.
    Expects a POST request with 'menu_item_id' and 'quantity'.
    """
    permission_classes = [IsAuthenticated, IsCustomer]

    def post(self, request, *args, **kwargs):
        menu_item_id = request.data.get('menu_item_id')
        quantity = request.data.get('quantity', 1)

        if not menu_item_id:
            return Response({'error': 'menu_item_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            menu_item = MenuItem.objects.get(pk=menu_item_id)
            quantity = int(quantity)
            if quantity <= 0:
                raise ValueError("Quantity must be positive.")
        except MenuItem.DoesNotExist:
            return Response({'error': 'Menu item not found'}, status=status.HTTP_404_NOT_FOUND)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid quantity'}, status=status.HTTP_400_BAD_REQUEST)

        cart, _ = Cart.objects.get_or_create(user=request.user)
        cart_item, created = CartItem.objects.get_or_create(
            cart=cart,
            menu_item=menu_item,
            defaults={'quantity': quantity}
        )

        if not created:
            # If item already exists, update its quantity
            cart_item.quantity += quantity
            cart_item.save()

        serializer = CartItemSerializer(cart_item)
        return Response(serializer.data, status=status.HTTP_200_OK)


class RemoveFromCartView(APIView):
    permission_classes = [IsAuthenticated, IsCustomer]

    def post(self, request, *args, **kwargs):
        cart_item_id = request.data.get('cart_item_id')

        if not cart_item_id:
            return Response({'error': 'cart_item_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            cart_item = CartItem.objects.get(pk=cart_item_id, cart__user=request.user)
            cart_item.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except CartItem.DoesNotExist:
            return Response({'error': 'Cart item not found'}, status=status.HTTP_404_NOT_FOUND)


class UpdateCartItemView(APIView):
    permission_classes = [IsAuthenticated, IsCustomer]

    def put(self, request, item_id, *args, **kwargs):
        quantity = request.data.get('quantity')

        if not quantity:
            return Response({'error': 'quantity is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            quantity = int(quantity)
            if quantity <= 0:
                # If quantity is zero or less, remove the item
                cart_item = CartItem.objects.get(pk=item_id, cart__user=request.user)
                cart_item.delete()
                return Response(status=status.HTTP_204_NO_CONTENT)

            cart_item = CartItem.objects.get(pk=item_id, cart__user=request.user)
            cart_item.quantity = quantity
            cart_item.save()
            serializer = CartItemSerializer(cart_item)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except CartItem.DoesNotExist:
            return Response({'error': 'Cart item not found'}, status=status.HTTP_404_NOT_FOUND)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid quantity'}, status=status.HTTP_400_BAD_REQUEST)



class CartItemViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsCustomer]

    def get_serializer_class(self):
        return CartItemWriteSerializer if self.action in ['create', 'update', 'partial_update'] else CartItemSerializer

    def get_queryset(self):
        return CartItem.objects.filter(cart__user=self.request.user).select_related('menu_item__category__restaurant')

class OrderListCreateView(generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        order = serializer.save(user=self.request.user)
        
        # Send WebSocket notification (separate try-catch to not block Firebase)
        try:
            channel_layer = get_channel_layer()
            if channel_layer:
                restaurant_id = order.restaurant.id
                order_data = RestaurantOrderSerializer(order, context={'request': self.request}).data
                async_to_sync(channel_layer.group_send)(
                    f'restaurant_{restaurant_id}',
                    {
                        'type': 'new_order',
                        'order': json.dumps(order_data, cls=DjangoJSONEncoder)
                    }
                )
                logger.info(f'Sent WebSocket notification for order {order.id} to group restaurant_{restaurant_id}')
        except Exception as e:
            logger.error(f'Failed to send WebSocket notification for order {order.id}: {e}')
        
        # Send Firebase push notification to restaurant (separate try-catch)
        try:
            logger.info(f'🔔 Attempting to send restaurant notification for new order {order.id}')
            self._send_restaurant_notification(order)
            logger.info(f'✅ Restaurant notification process completed for order {order.id}')
        except Exception as e:
            logger.error(f'❌ Failed to send Firebase notification for order {order.id}: {e}', exc_info=True)
    
    def _send_restaurant_notification(self, order):
        """Send Firebase push notification to restaurant about new order"""
        try:
            # Get restaurant owner
            restaurant_owner = order.restaurant.owner
            logger.info(f'🏪 Sending notification to restaurant owner: {restaurant_owner.username} (ID: {restaurant_owner.id})')
            
            # Get active devices for restaurant owner
            active_devices = Device.objects.filter(
                user=restaurant_owner,
                is_active=True,
                device_type='restaurant'
            )
            
            logger.info(f'📱 Found {active_devices.count()} active restaurant devices for user {restaurant_owner.id}')
            
            # Also check all devices for this user (for debugging)
            all_devices = Device.objects.filter(user=restaurant_owner)
            logger.info(f'📱 Total devices for user {restaurant_owner.id}: {all_devices.count()}')
            for device in all_devices:
                logger.info(f'   Device: {device.id}, Type: {device.device_type}, Active: {device.is_active}, Token: {device.token[:20]}...')
            
            if active_devices.exists():
                logger.info(f'📤 Sending Firebase notification to {active_devices.count()} restaurant devices')
                # Send notification to restaurant
                notification_sent = send_push_notification(
                    restaurant_owner,
                    f"🍽️ New Order #{order.id}",
                    f"New order from {order.user.get_full_name() or order.user.username} - UGX {order.total_price:,.0f}",
                    data={
                        'order_id': str(order.id),
                        'customer_name': order.user.get_full_name() or order.user.username,
                        'total_price': str(order.total_price),
                        'type': 'new_order'
                    }
                )
                
                if notification_sent:
                    logger.info(f'✅ Successfully sent Firebase notification for order {order.id} to restaurant {order.restaurant.name}')
                else:
                    logger.error(f'❌ Failed to send Firebase notification for order {order.id} - notification_sent returned False')
            else:
                logger.warning(f'📱 No active restaurant devices found for order {order.id} - Restaurant owner {restaurant_owner.username} needs to login to restaurant app')
                
        except Exception as e:
            logger.error(f'❌ Error sending restaurant notification for order {order.id}: {e}')

class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(user=self.request.user)

class OrderUpdateStatusView(generics.UpdateAPIView):
    """Allows a restaurant or rider to update the status of an order."""
    queryset = Order.objects.all()
    serializer_class = OrderUpdateStatusSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'pk'

    def update(self, request, *args, **kwargs):
        order = self.get_object()
        old_status = order.status
        response = super().update(request, *args, **kwargs)

        if response.status_code == 200:
            order.refresh_from_db()
            new_status = order.status

            # If status has changed, send notifications
            if old_status != new_status:
                logger.info(f"Order {order.id} status changed from {old_status} to {new_status}. Sending notifications.")
                
                # The generic notification was removed to prevent duplicates.
                # Specific notifications are handled below and in other views.

                # Broadcast the status update to the restaurant's dashboard via WebSocket
                try:
                    channel_layer = get_channel_layer()
                    if channel_layer and order.restaurant:
                        restaurant_group_name = f'restaurant_{order.restaurant.id}'
                        serializer = RestaurantOrderSerializer(order, context={'request': request})
                        updated_order_data = serializer.data
                        async_to_sync(channel_layer.group_send)(
                            restaurant_group_name,
                            {
                                'type': 'order_update',
                                'order': updated_order_data
                            }
                        )
                        logger.info(f"Sent order status update for order {order.id} to group {restaurant_group_name}")
                except ConnectionError as e:
                    logger.debug(f"Redis connection unavailable for WebSocket notification (order {order.id}): {e}")
                    # Continue execution - WebSocket failure shouldn't break order updates
                except Exception as e:
                    logger.warning(f"Failed to send WebSocket notification for order {order.id}: Error {e}")
                    # Continue execution - WebSocket failure shouldn't break order updates

                # Send restaurant notifications for key status changes
                if order.restaurant and order.restaurant.owner:
                    restaurant_title = ""
                    restaurant_body = ""
                    
                    if new_status == 'Accepted':
                        restaurant_title = f"Order #{order.id} Confirmed"
                        restaurant_body = f"Order from {order.user.get_full_name() or order.user.username} has been confirmed."
                    elif new_status == 'Preparing':
                        restaurant_title = f"Order #{order.id} In Progress"
                        restaurant_body = f"Kitchen has started preparing order from {order.user.get_full_name() or order.user.username}."
                    elif new_status == 'En route to Restaurant' and order.rider:
                        restaurant_title = f"Rider Assigned - Order #{order.id}"
                        restaurant_body = f"{order.rider.user.username} has accepted the delivery and is en route to your restaurant."
                    elif new_status == 'Picked up':
                        restaurant_title = f"Order #{order.id} Picked Up"
                        restaurant_body = f"Rider has picked up the order and is heading to the customer."
                    elif new_status == 'Delivered':
                        restaurant_title = f"Order #{order.id} Delivered"
                        restaurant_body = f"Order has been successfully delivered to {order.user.get_full_name() or order.user.username}."
                    
                    if restaurant_title and restaurant_body:
                        send_push_notification(
                            order.restaurant.owner,
                            restaurant_title,
                            restaurant_body,
                            data={'orderId': str(order.id), 'status': new_status, 'type': 'status_update'}
                        )

            # If order is ready, notify available riders via WebSocket and Push Notification
            if new_status == 'Ready for Pickup':
                # 1. Notify via WebSocket (existing functionality)
                try:
                    channel_layer = get_channel_layer()
                    if channel_layer:
                        order_serializer = RestaurantOrderSerializer(order)
                        async_to_sync(channel_layer.group_send)(
                            'riders_available',
                            {'type': 'new_order_message', 'order': order_serializer.data}
                        )
                        logger.info(f"Sent 'Ready for Pickup' WebSocket message for order {order.id} to riders_available group.")
                except ConnectionError as e:
                    logger.debug(f"Redis connection unavailable for rider WebSocket notification (order {order.id}): {e}")
                except Exception as e:
                    logger.warning(f"Failed to send rider WebSocket notification for order {order.id}: {e}")

                # 2. Send Push Notifications to all available riders
                try:
                    available_riders = RiderProfile.objects.filter(is_available=True)
                    if not available_riders.exists():
                        logger.warning(f"Order {order.id} is ready, but no riders are currently available.")
                    else:
                        notification_title = "New Delivery Available!"
                        notification_body = f"Order #{order.id} from {order.restaurant.name} is ready for pickup."
                        notification_data = {'orderId': str(order.id), 'status': new_status}
                        
                        for rider_profile in available_riders:
                            send_push_notification(
                                user=rider_profile.user,
                                title=notification_title,
                                body=notification_body,
                                data=notification_data
                            )
                        logger.info(f"Sent push notifications for order {order.id} to {available_riders.count()} available riders.")
                except Exception as e:
                    logger.error(f"Failed to send 'Ready for Pickup' push notifications for order {order.id}: {e}", exc_info=True)

        return response


class NotifyArrivalView(APIView):
    """Allows a rider to notify the customer that they are arriving soon."""
    permission_classes = [IsAuthenticated]

    def post(self, request, order_id, *args, **kwargs):
        try:
            order = Order.objects.get(id=order_id)
            rider_profile = get_object_or_404(RiderProfile, user=request.user)

            # Check if the authenticated user is the rider assigned to this order
            if order.rider != rider_profile:
                return Response({'error': 'You are not assigned to this order.'}, status=status.HTTP_403_FORBIDDEN)

            # Send notification to the customer
            customer = order.user
            send_push_notification(
                customer,
                title="Your rider is arriving!",
                body=f"{request.user.username} is just moments away with your order.",
                data={'orderId': str(order.id), 'status': 'Arriving'}
            )

            return Response({'status': 'Notification sent to customer.'}, status=status.HTTP_200_OK)

        except Order.DoesNotExist:
            return Response({'error': 'Order not found.'}, status=status.HTTP_404_NOT_FOUND)

# --- User and Auth Views ---

class CreateUserView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

class RestaurantSignUpView(generics.CreateAPIView):
    queryset = User.objects.all()
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = RestaurantSignUpSerializer
    permission_classes = [AllowAny]

class RiderSignUpView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RiderSignUpSerializer
    permission_classes = [AllowAny]

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')
        user = authenticate(username=username, password=password)
        if user:
            login(request, user)
            return Response(UserSerializer(user).data)
        return Response({'error': 'Invalid Credentials'}, status=status.HTTP_401_UNAUTHORIZED)

class LogoutView(APIView):
    def post(self, request):
        logout(request)
        return Response(status=status.HTTP_204_NO_CONTENT)

class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

# --- Other Views ---


class AssignOrderToRiderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id, status='Ready for Pickup')
            rider_profile = RiderProfile.objects.get(user=request.user)
            order.rider = rider_profile
            order.status = 'En Route to Restaurant'
            order.save()
            send_push_notification(
                order.user,
                title=f"Your order #{order.id} is on its way!",
                body=f"{rider_profile.user.username} is coming to pick up your order.",
                data={'orderId': str(order.id), 'status': order.status}
            )
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found or not ready for pickup.'}, status=status.HTTP_404_NOT_FOUND)
        except RiderProfile.DoesNotExist:
            return Response({'error': 'Rider profile not found.'}, status=status.HTTP_403_FORBIDDEN)



class AvailableOrderListView(generics.ListAPIView):
    """
    Lists all orders that are ready for pickup and have not been assigned to a rider.
    """
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    queryset = Order.objects.filter(status='Ready for Pickup', rider__isnull=True).order_by('-created_at')

    def post(self, request, *args, **kwargs):
        order_id = request.data.get('order_id')
        if not order_id:
            return Response({'error': 'Order ID is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=order_id, status='Ready for Pickup', rider__isnull=True)
        except Order.DoesNotExist:
            return Response({'error': 'This order is not available or does not exist.'}, status=status.HTTP_404_NOT_FOUND)

        order.rider = request.user
        order.status = 'Accepted'
        order.save()

        serializer = self.get_serializer(order)
        return Response(serializer.data, status=status.HTTP_200_OK)


from rest_framework.parsers import MultiPartParser, FormParser



class MenuItemBulkUploadView(generics.CreateAPIView):
    serializer_class = MenuItemBulkUploadSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return Response(result, status=status.HTTP_201_CREATED)


class ModifierGroupViewSet(viewsets.ModelViewSet):
    queryset = ModifierGroup.objects.all()
    serializer_class = ModifierGroupSerializer
    permission_classes = [IsAuthenticated]




class DashboardMenuView(generics.ListAPIView):
    """
    API endpoint for the restaurant owner's dashboard to view their menu items.
    """
    serializer_class = MenuItemSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        # Get the restaurant associated with the logged-in user
        try:
            restaurant = Restaurant.objects.get(owner=self.request.user)
            # Return all menu items for that restaurant
            return MenuItem.objects.filter(category__restaurant=restaurant)
        except Restaurant.DoesNotExist:
            # If no restaurant is associated with the user, return an empty queryset
            return MenuItem.objects.none()

class DashboardAnalyticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        # Get the restaurant owned by the logged-in user
        try:
            restaurant = Restaurant.objects.get(owner=request.user)
        except Restaurant.DoesNotExist:
            return Response({"error": "No restaurant associated with this user."}, status=status.HTTP_404_NOT_FOUND)

        # 1. Calculate Header Stats
        today = timezone.now().date()
        completed_orders = Order.objects.filter(restaurant=restaurant, status='Delivered')
        total_income = completed_orders.aggregate(total=Sum('total_price'))['total'] or 0

        all_orders = Order.objects.filter(restaurant=restaurant)
        total_orders_count = all_orders.count()

        # Calculate today's stats
        todays_orders = all_orders.filter(created_at__date=today)
        daily_income = todays_orders.filter(status='Delivered').aggregate(total=Sum('total_price'))['total'] or 0
        daily_orders_count = todays_orders.count()

        # Calculate pending orders from the complete list
        pending_statuses = ['Pending', 'Accepted', 'Preparing']
        pending_orders_count = all_orders.filter(status__in=pending_statuses).count()
        pending_income = all_orders.filter(status__in=pending_statuses).aggregate(total=Sum('total_price'))['total'] or 0

        # 2. Calculate Order Rate (e.g., last 12 months)
        order_rate_data = (
            Order.objects.filter(
                restaurant=restaurant,
                created_at__gte=timezone.now() - timedelta(days=365)
            )
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=Count('id'))
            .order_by('month')
        )

        # Format for chart
        order_rate = [
            {"month": item['month'].strftime('%b'), "orders": item['count']}
            for item in order_rate_data
        ]

        # 3. Calculate Popular Food Items
        popular_items_data = (
            OrderItem.objects.filter(
                order__restaurant=restaurant,
                menu_item__category__restaurant=restaurant  # Ensure menu item belongs to this restaurant
            )
            .values('menu_item__name', 'menu_item__image')
            .annotate(count=Count('id'))
            .order_by('-count')[:5]  # Top 5 items
        )

        popular_items = [
            {
                "name": item['menu_item__name'],
                "count": item['count'],
                "image": request.build_absolute_uri(f"/media/{item['menu_item__image']}") if item['menu_item__image'] else None,
            }
            for item in popular_items_data
        ]

        # 4. Assemble the response
        data = {
            'total_income': total_income,
            'total_orders': total_orders_count,
            'pending_orders': pending_orders_count,
            'pending_income': pending_income,
            'daily_income': daily_income,
            'daily_orders': daily_orders_count,
            'order_rate': order_rate,
            'popular_items': popular_items,
        }

        return Response(data, status=status.HTTP_200_OK)

class RestaurantDashboardMenuView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = self.request.user
        try:
            # Ensure the user has a restaurant profile.
            restaurant = user.restaurant_profile
            
            # Get the categories and their related menu items.
            queryset = MenuCategory.objects.filter(restaurant=restaurant).prefetch_related('menu_items')
            
            # Manually serialize the data to ensure the correct structure.
            serializer = MenuCategorySerializer(queryset, many=True)
            
            # Return the data within the 'categories' key as expected by the frontend.
            return Response({'categories': serializer.data}, status=status.HTTP_200_OK)
            
        except Restaurant.DoesNotExist:
            # If the user is not a restaurant owner, return an empty set.
            return Response({'categories': []}, status=status.HTTP_200_OK)
        except AttributeError:
            # Catches cases where user.restaurant_profile doesn't exist
            return Response({'categories': []}, status=status.HTTP_200_OK)


class RestaurantOrderViewSet(viewsets.ReadOnlyModelViewSet):
    """
    This view returns a list of all orders for the restaurant
    owned by the currently authenticated user.
    """
    serializer_class = RestaurantOrderSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        user = self.request.user
        try:
            # The user's restaurant profile is now directly on the unified Restaurant model.
            restaurant = user.restaurant_profile
            return Order.objects.filter(restaurant=restaurant).order_by('-created_at')
        except (Restaurant.DoesNotExist, AttributeError):
            # This will catch cases where the user is not a restaurant owner
            # or the restaurant_profile attribute doesn't exist.
            return Order.objects.none()


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for viewing user notifications."""
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """This view should return a list of all the notifications
        for the currently authenticated user."""
        return self.request.user.notifications.all()

    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        """Mark a specific notification as read."""
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'notification marked as read'})


class MessageViewSet(viewsets.ModelViewSet):
    """ViewSet for handling messages between users."""
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """This view should return a list of all messages for the currently authenticated user."""
        user = self.request.user
        # Return messages where the user is either the sender or the recipient
        return Message.objects.filter(Q(sender=user) | Q(recipient=user)).order_by('-timestamp')

    def perform_create(self, serializer):
        """Set the sender of the message to the currently authenticated user."""
        serializer.save(sender=self.request.user)


class CurrentUserView(APIView):
    """View to get the current authenticated user's data."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return the data for the currently authenticated user."""
        serializer = UserSerializer(request.user)
        return Response(serializer.data)


class MenuItemViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows menu items to be viewed or edited.
    """
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = MenuItemSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        """
        This view should return a list of all the menu items
        for the currently authenticated restaurant.
        """
        try:
            restaurant = self.request.user.restaurant_profile
            return MenuItem.objects.filter(category__restaurant=restaurant)
        except Restaurant.DoesNotExist:
            return MenuItem.objects.none()
        except AttributeError:
            # Handle cases where user is not a restaurant owner or has no profile
            return MenuItem.objects.none()

    def perform_create(self, serializer):
        """
        Ensure the category belongs to the user's restaurant.
        """
        category = serializer.validated_data.get('category')
        try:
            restaurant = self.request.user.restaurant_profile
            if category is None:
                raise ValidationError("Category is required.")
            if category.restaurant != restaurant:
                raise ValidationError("You can only add items to your own restaurant's categories.")
            serializer.save()
        except Restaurant.DoesNotExist:
            raise ValidationError("User is not associated with a restaurant.")



class MenuCategoryViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows restaurants to manage their menu categories.
    """
    serializer_class = MenuCategoryCRUDSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        """
        This view should return a list of all the categories
        for the currently authenticated restaurant.
        """
        try:
            restaurant = self.request.user.restaurant_profile
            return MenuCategory.objects.filter(restaurant=restaurant)
        except Restaurant.DoesNotExist:
            return MenuCategory.objects.none()
        except AttributeError:
            return MenuCategory.objects.none()

    def perform_create(self, serializer):
        """
        Associate the category with the logged-in user's restaurant.
        """
        try:
            restaurant = self.request.user.restaurant_profile
            serializer.save(restaurant=restaurant)
        except Restaurant.DoesNotExist:
            # This case should ideally not happen if IsRestaurantOwner permission is checked
            pass


class BillViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = BillSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        try:
            restaurant = Restaurant.objects.get(owner=user)
            return Bill.objects.filter(restaurant=restaurant).order_by('-created_at')
        except Restaurant.DoesNotExist:
            return Bill.objects.none()


class PaymentPeriodViewSet(viewsets.ReadOnlyModelViewSet):
    """API for viewing payment periods (weekly/daily summaries)"""
    serializer_class = PaymentPeriodSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]
    
    def get_queryset(self):
        try:
            restaurant = self.request.user.restaurant_profile
            return PaymentPeriod.objects.filter(restaurant=restaurant)
        except Restaurant.DoesNotExist:
            return PaymentPeriod.objects.none()
    
    @action(detail=False, methods=['get'])
    def current_week(self):
        """Get current week's payment period"""
        from django.utils import timezone
        from datetime import timedelta
        
        try:
            restaurant = self.request.user.restaurant_profile
            now = timezone.now()
            # Calculate start of current week (Monday)
            start_of_week = now - timedelta(days=now.weekday())
            start_of_week = start_of_week.replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_week = start_of_week + timedelta(days=7)
            
            period, created = PaymentPeriod.objects.get_or_create(
                restaurant=restaurant,
                period_type='weekly',
                start_date=start_of_week,
                end_date=end_of_week,
                defaults={'status': 'pending'}
            )
            
            serializer = self.get_serializer(period)
            return Response(serializer.data)
        except Restaurant.DoesNotExist:
            return Response({'error': 'Restaurant not found'}, status=404)


class OrderPaymentViewSet(viewsets.ReadOnlyModelViewSet):
    """API for viewing detailed order payment breakdowns"""
    serializer_class = OrderPaymentSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]
    
    def get_queryset(self):
        try:
            restaurant = self.request.user.restaurant_profile
            queryset = OrderPayment.objects.filter(payment_period__restaurant=restaurant)
            
            # Filter by payment period if provided
            period_id = self.request.query_params.get('period_id')
            if period_id:
                queryset = queryset.filter(payment_period_id=period_id)
            
            # Filter by date range
            start_date = self.request.query_params.get('start_date')
            end_date = self.request.query_params.get('end_date')
            if start_date and end_date:
                queryset = queryset.filter(order_date__range=[start_date, end_date])
            
            return queryset
        except Restaurant.DoesNotExist:
            return OrderPayment.objects.none()


class BankAccountViewSet(viewsets.ModelViewSet):
    """API for managing restaurant bank account information"""
    serializer_class = BankAccountSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]
    
    def get_queryset(self):
        try:
            restaurant = self.request.user.restaurant_profile
            return BankAccount.objects.filter(restaurant=restaurant)
        except Restaurant.DoesNotExist:
            return BankAccount.objects.none()
    
    def perform_create(self, serializer):
        restaurant = self.request.user.restaurant_profile
        serializer.save(restaurant=restaurant)


class PaymentDisputeViewSet(viewsets.ModelViewSet):
    """API for managing payment disputes and refunds"""
    serializer_class = PaymentDisputeSerializer
    permission_classes = [IsAuthenticated, IsRestaurantOwner]
    
    def get_queryset(self):
        try:
            restaurant = self.request.user.restaurant_profile
            return PaymentDispute.objects.filter(
                order_payment__payment_period__restaurant=restaurant
            )
        except Restaurant.DoesNotExist:
            return PaymentDispute.objects.none()
    
    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        """Allow restaurant to respond to a dispute"""
        dispute = self.get_object()
        response_text = request.data.get('response')
        
        if not response_text:
            return Response({'error': 'Response text is required'}, status=400)
        
        dispute.restaurant_response = response_text
        dispute.status = 'under_review'
        dispute.save()
        
        serializer = self.get_serializer(dispute)
        return Response(serializer.data)


class RestaurantReviewsView(generics.ListAPIView):
    serializer_class = RestaurantDashboardReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        try:
            restaurant = Restaurant.objects.get(owner=user)
            return OrderReview.objects.filter(order__restaurant=restaurant).order_by('-created_at')
        except Restaurant.DoesNotExist:
            return OrderReview.objects.none()


class RestaurantProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = RestaurantSerializer
    parser_classes = [MultiPartParser, FormParser]
    permission_classes = [IsAuthenticated]

    def get_object(self):
        # Use the related_name we defined in the model
        return self.request.user.restaurant_profile


class RiderOrderViewSet(viewsets.ReadOnlyModelViewSet):
    """
    This viewset handles listing and managing a rider's orders.
    It uses the RiderOrderSerializer to include customer contact details.
    """
    serializer_class = RiderOrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """This view should return a list of all the orders assigned to the currently authenticated rider."""
        user = self.request.user
        if hasattr(user, 'rider_profile'):
            return Order.objects.filter(rider=user.rider_profile).order_by('-created_at')
        return Order.objects.none() # Return no orders if the user is not a rider

    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        """
        Allows a rider to accept an order that is 'Ready for Pickup'.
        """
        try:
            order = Order.objects.get(pk=pk, status='Ready for Pickup', rider__isnull=True)
        except Order.DoesNotExist:
            return Response({'error': 'This order is no longer available.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            rider_profile = RiderProfile.objects.get(user=request.user)
            order.rider = rider_profile
            order.status = 'Out for Delivery'
            order.save()

            # Notify customer and restaurant
            send_order_status_notification(order)

            return Response(OrderSerializer(order).data)
        except RiderProfile.DoesNotExist:
            return Response({'error': 'Rider profile not found.'}, status=status.HTTP_403_FORBIDDEN)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """
        Allows a rider to mark an order as delivered.
        """
        try:
            # .get_queryset() already filters for the current rider
            order = self.get_queryset().get(pk=pk)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found or not assigned to you.'}, status=status.HTTP_404_NOT_FOUND)
        
        # Check if order can be completed
        if order.status not in ['Out for Delivery', 'Ready for Pickup', 'Rider Arrived']:
            return Response({
                'error': f'Order cannot be completed. Current status: {order.status}. Order must be "Out for Delivery", "Ready for Pickup", or "Rider Arrived".'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # If order is "Ready for Pickup", automatically assign to rider and set to "Out for Delivery"
        if order.status == 'Ready for Pickup':
            try:
                rider_profile = RiderProfile.objects.get(user=request.user)
                order.rider = rider_profile
                order.status = 'Out for Delivery'
                order.save()
                # Notify about pickup
                send_order_status_notification(order)
            except RiderProfile.DoesNotExist:
                return Response({'error': 'Rider profile not found.'}, status=status.HTTP_403_FORBIDDEN)

        order.status = 'Delivered'
        order.save()

        # Notify customer
        send_order_status_notification(order)

        # Notify restaurant
        channel_layer = get_channel_layer()
        restaurant_group_name = f'restaurant_{order.restaurant.id}'
        order_data = RestaurantOrderSerializer(order).data
        async_to_sync(channel_layer.group_send)(
            restaurant_group_name,
            {
                'type': 'order_update',
                'order': order_data
            }
        )

        # Award loyalty points
        points, _ = LoyaltyService.calculate_points(order)
        LoyaltyService.award_points(order.user, points, 'order_completion', order)

        serializer = self.get_serializer(order)
        return Response(serializer.data, status=status.HTTP_200_OK)


class DirectionsProxyView(APIView):
    """
    A proxy view to fetch directions from the Google Maps API.
    This is necessary to avoid CORS issues on the web client.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        origin = request.query_params.get('origin')
        destination = request.query_params.get('destination')
        api_key = getattr(settings, 'GOOGLE_MAPS_API_KEY', None)

        if not all([origin, destination, api_key]):
            return Response(
                {'error': 'Missing required parameters: origin, destination, and API key.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        url = f"https://maps.googleapis.com/maps/api/directions/json?origin={origin}&destination={destination}&key={api_key}"

        try:
            response = requests.get(url)
            response.raise_for_status()  # Raise an exception for bad status codes
            return Response(response.json())
        except requests.exceptions.RequestException as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RestaurantSignUpView(generics.CreateAPIView):
    """
    A view for new restaurants to sign up. This creates a new User and a new Restaurant instance.
    """
    queryset = Restaurant.objects.all()
    serializer_class = RestaurantSignUpSerializer
    permission_classes = [AllowAny] # Anyone can sign up

class RiderSignUpView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [permissions.AllowAny]
    serializer_class = RiderSignUpSerializer


class DietaryPreferenceViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Provides a read-only list of available dietary preferences.
    """
    queryset = DietaryPreference.objects.all()
    serializer_class = DietaryPreferenceSerializer
    permission_classes = [permissions.IsAuthenticated]


class UserAddressViewSet(viewsets.ModelViewSet):
    """
    Allows users to manage their saved addresses.
    """
    serializer_class = UserAddressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """
        This view should return a list of all the addresses
        for the currently authenticated user.
        """
        return UserAddress.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ReviewViewSet(viewsets.ModelViewSet):
    """ViewSet for creating and listing reviews."""
    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        """Optionally restricts the returned reviews to a given menu item."""
        queryset = Review.objects.all()
        menu_item_id = self.request.query_params.get('menu_item_id')
        if menu_item_id is not None:
            queryset = queryset.filter(menu_item_id=menu_item_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)




class CustomerProfileView(generics.RetrieveUpdateAPIView):
    """
    Allows the current user to retrieve and update their customer profile.
    """
    serializer_class = CustomerProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        """
        Retrieve or create the profile for the current user.
        """
        profile, created = CustomerProfile.objects.get_or_create(user=self.request.user)
        return profile


class RestaurantProfileView(generics.RetrieveUpdateAPIView):
    """
    Allows authenticated restaurant owners to view and update their restaurant profile.
    """
    permission_classes = [IsAuthenticated, IsRestaurantOwner]
    serializer_class = RestaurantProfileSerializer
    parser_classes = [MultiPartParser, FormParser]

    def get_object(self):
        # The IsRestaurantOwner permission ensures request.user.restaurant_profile exists
        return self.request.user.restaurant_profile


class RestaurantOrderReviewViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = RestaurantOrderReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        try:
            # Assuming the user model has a related 'restaurant' object
            restaurant = Restaurant.objects.get(owner=user)
            return OrderReview.objects.filter(restaurant=restaurant).order_by('-created_at')
        except Restaurant.DoesNotExist:
            return OrderReview.objects.none()

    @action(detail=True, methods=['post'], url_path='reply')
    def reply_to_review(self, request, pk=None):
        review = self.get_object()
        reply_text = request.data.get('reply_text')

        if not reply_text:
            return Response({'error': 'Reply text cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)

        if review.reply_text:
            return Response({'error': 'This review has already been replied to.'}, status=status.HTTP_400_BAD_REQUEST)

        review.reply_text = reply_text
        review.replied_at = timezone.now()
        review.save()

        serializer = self.get_serializer(review)
        return Response(serializer.data)


class OrderReviewViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to create, view, and manage reviews for their orders.
    """
    serializer_class = OrderReviewSerializer
    permission_classes = [IsAuthenticated, IsCustomer]

    def get_queryset(self):
        """
        This view should only return reviews for the currently authenticated user.
        """
        return OrderReview.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        order_id = self.request.data.get('order')
        try:
            order = Order.objects.get(id=order_id, user=self.request.user)
        except Order.DoesNotExist:
            raise ValidationError("You can only review your own orders.")

        if not order.status == 'Delivered':
            raise ValidationError("You can only review delivered orders.")

        if OrderReview.objects.filter(order=order).exists():
            raise ValidationError("This order has already been reviewed.")

        serializer.save(user=self.request.user, restaurant=order.restaurant)


class RiderReviewViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to create, view, and manage reviews for riders.
    """
    serializer_class = RiderReviewSerializer
    permission_classes = [IsAuthenticated, IsCustomer]

    def get_queryset(self):
        """
        This view should only return rider reviews for the currently authenticated user.
        """
        return RiderReview.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class MyRiderReviewsView(generics.ListAPIView):
    """
    API endpoint that allows an authenticated rider to view their reviews.
    """
    serializer_class = RiderReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        Returns reviews for the current rider.
        """
        try:
            rider_profile = self.request.user.rider_profile
            return RiderReview.objects.filter(rider=rider_profile).order_by('-created_at')
        except RiderProfile.DoesNotExist:
            return RiderReview.objects.none()


# Password Recovery Views
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.contrib.auth import get_user_model

User = get_user_model()

@api_view(['POST'])
@permission_classes([AllowAny])
def password_reset_request(request):
    """
    Send password reset email to user
    """
    try:
        email = request.data.get('email')
        if not email:
            return Response({
                'error': 'Email is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Don't reveal if email exists or not for security
            return Response({
                'message': 'If an account with this email exists, you will receive a password reset link.'
            }, status=status.HTTP_200_OK)
        
        # Generate token and uid
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        
        # Create reset link (you can customize this URL)
        reset_link = f"https://food-delivery-backend-2mcb.onrender.com/reset-password/{uid}/{token}/"
        
        # Send email (you'll need to configure email settings)
        subject = 'FortXpress - Password Reset Request'
        message = f"""
        Hello {user.get_full_name() or user.username},
        
        You requested a password reset for your FortXpress account.
        
        Click the link below to reset your password:
        {reset_link}
        
        If you didn't request this, please ignore this email.
        
        Best regards,
        FortXpress Team
        """
        
        try:
            send_mail(
                subject,
                message,
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            logger.info(f"Password reset email sent to {email}")
        except Exception as e:
            logger.error(f"Failed to send password reset email to {email}: {e}")
            # For now, we'll still return success to not reveal email existence
        
        return Response({
            'message': 'If an account with this email exists, you will receive a password reset link.'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Password reset request error: {e}")
        return Response({
            'error': 'An error occurred while processing your request'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([AllowAny])
def password_reset_confirm(request):
    """
    Confirm password reset with token
    """
    try:
        uid = request.data.get('uid')
        token = request.data.get('token')
        new_password = request.data.get('new_password')
        
        if not all([uid, token, new_password]):
            return Response({
                'error': 'UID, token, and new password are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate password length
        if len(new_password) < 8:
            return Response({
                'error': 'Password must be at least 8 characters long'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Decode uid
            user_id = force_str(urlsafe_base64_decode(uid))
            user = User.objects.get(pk=user_id)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            return Response({
                'error': 'Invalid reset link'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check token validity
        if not default_token_generator.check_token(user, token):
            return Response({
                'error': 'Invalid or expired reset link'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Set new password
        user.set_password(new_password)
        user.save()
        
        logger.info(f"Password reset successful for user {user.email}")
        
        return Response({
            'message': 'Password has been reset successfully'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Password reset confirm error: {e}")
        return Response({
            'error': 'An error occurred while resetting your password'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """
    Change password for authenticated user
    """
    try:
        current_password = request.data.get('current_password')
        new_password = request.data.get('new_password')
        
        if not all([current_password, new_password]):
            return Response({
                'error': 'Current password and new password are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate current password
        if not request.user.check_password(current_password):
            return Response({
                'error': 'Current password is incorrect'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate new password length
        if len(new_password) < 8:
            return Response({
                'error': 'New password must be at least 8 characters long'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Set new password
        request.user.set_password(new_password)
        request.user.save()
        
        logger.info(f"Password changed successfully for user {request.user.email}")
        
        return Response({
            'message': 'Password changed successfully'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Change password error: {e}")
        return Response({
            'error': 'An error occurred while changing your password'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Payment Views
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def initiate_payment(request):
    """Initiate a payment for an order"""
    # Debug logging
    logger.info(f"Payment initiation request data: {request.data}")
    logger.info(f"Request headers: {dict(request.headers)}")
    logger.info(f"Request method: {request.method}")
    logger.info(f"Request path: {request.path}")
    
    # Handle missing payment_method by defaulting to pesapal if not provided
    request_data = request.data.copy()
    if 'payment_method' not in request_data:
        logger.warning("payment_method missing, defaulting to pesapal")
        request_data['payment_method'] = 'pesapal'
    
    # Handle phone vs phone_number field name inconsistency
    if 'phone' in request_data and 'phone_number' not in request_data:
        logger.warning("Converting 'phone' field to 'phone_number'")
        request_data['phone_number'] = request_data.pop('phone')
    
    serializer = PaymentInitiateSerializer(data=request_data)
    
    if not serializer.is_valid():
        # Convert serializer errors to a readable string
        error_messages = []
        for field, errors in serializer.errors.items():
            for error in errors:
                error_messages.append(f"{field}: {error}")
        error_message = "; ".join(error_messages) if error_messages else "Invalid data provided"
        logger.error(f"Payment validation failed: {error_message}")
        return Response({'error': error_message}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        order_id = serializer.validated_data['order_id']
        payment_method = serializer.validated_data['payment_method']
        amount = serializer.validated_data['amount']
        phone_number = serializer.validated_data.get('phone_number')
        
        # Get the order
        try:
            order = Order.objects.get(id=order_id, user=request.user)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Check if payment already exists
        if hasattr(order, 'payment'):
            return Response({'error': 'Payment already exists for this order'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Create payment record
        payment = Payment.objects.create(
            order=order,
            method=payment_method,
            amount=amount,
            phone_number=phone_number,
            status='pending'
        )
        
        # Generate reference number
        payment.reference = f"PAY{payment.id:06d}"
        payment.save()
        
        if payment_method == 'cash_on_delivery':
            # For cash on delivery, mark as completed immediately
            payment.status = 'completed'
            payment.save()
            
            return Response({
                'payment_id': payment.id,
                'reference': payment.reference,
                'message': 'Cash on delivery payment confirmed'
            }, status=status.HTTP_200_OK)
        
        elif payment_method in ['mtn_mobile_money', 'airtel_money']:
            # For mobile money, initiate the payment process
            payment.status = 'processing'
            payment.save()
            
            # Here you would integrate with MTN/Airtel APIs
            # For now, we'll simulate the process
            
            return Response({
                'payment_id': payment.id,
                'reference': payment.reference,
                'message': f'Payment request sent to {phone_number}. Please check your phone to complete the payment.'
            }, status=status.HTTP_200_OK)
        
        elif payment_method == 'pesapal':
            # For Pesapal, initiate the payment process
            payment.status = 'processing'
            payment.save()
            
            # Here you would integrate with Pesapal API
            # For now, we'll return the payment details for frontend handling
            
            return Response({
                'success': True,
                'payment_id': payment.id,
                'reference': payment.reference,
                'redirect_url': f'https://demo.pesapal.com/API/PostPesapalDirectOrderV4?reference={payment.reference}&amount={amount}&description=Order%20Payment',  # More realistic Pesapal URL
                'message': 'Payment initiated successfully. You will be redirected to Pesapal.'
            }, status=status.HTTP_200_OK)
        
        else:
            return Response({'error': f'Payment method {payment_method} not supported'}, status=status.HTTP_400_BAD_REQUEST)
        
    except Exception as e:
        logger.error(f"Payment initiation error: {e}")
        return Response({'error': 'Failed to initiate payment'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_payment_status(request, payment_id):
    """Check the status of a payment"""
    try:
        payment = Payment.objects.get(id=payment_id, order__user=request.user)
        
        # For mobile money and Pesapal payments, simulate completion
        # In production, you would check with the actual provider APIs
        if payment.status == 'processing':
            import random
            
            if payment.method in ['mtn_mobile_money', 'airtel_money']:
                # 33% chance of completion for mobile money
                if random.choice([True, False, False]):
                    payment.status = 'completed'
                    payment.transaction_id = f"TXN{payment.id:08d}"
                    payment.save()
            
            elif payment.method == 'pesapal':
                # 50% chance of completion for Pesapal (higher success rate for demo)
                if random.choice([True, False]):
                    payment.status = 'completed'
                    payment.transaction_id = f"PESAPAL{payment.id:08d}"
                    payment.save()
                    
                    # Update order status to paid when payment is completed
                    if payment.order:
                        payment.order.status = 'confirmed'
                        payment.order.save()
        
        serializer = PaymentSerializer(payment)
        return Response({
            'status': payment.status,
            'transaction_id': payment.transaction_id,
            'message': f'Payment is {payment.status}',
            'payment': serializer.data
        }, status=status.HTTP_200_OK)
        
    except Payment.DoesNotExist:
        return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Payment status check error: {e}")
        return Response({'error': 'Failed to check payment status'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_payment(request, payment_id):
    """Cancel a pending payment"""
    try:
        payment = Payment.objects.get(id=payment_id, order__user=request.user)
        
        if payment.status not in ['pending', 'processing']:
            return Response({'error': 'Cannot cancel this payment'}, status=status.HTTP_400_BAD_REQUEST)
        
        payment.status = 'cancelled'
        payment.save()
        
        return Response({'message': 'Payment cancelled successfully'}, status=status.HTTP_200_OK)
        
    except Payment.DoesNotExist:
        return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Payment cancellation error: {e}")
        return Response({'error': 'Failed to cancel payment'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_payment(request, payment_id):
    """Manually complete a payment (for testing purposes)"""
    try:
        payment = Payment.objects.get(id=payment_id, order__user=request.user)
        
        if payment.status != 'processing':
            return Response({'error': 'Payment is not in processing state'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Complete the payment
        payment.status = 'completed'
        payment.transaction_id = f"MANUAL{payment.id:08d}"
        payment.save()
        
        # Update order status
        if payment.order:
            payment.order.status = 'confirmed'
            payment.order.save()
        
        return Response({
            'message': 'Payment completed successfully',
            'status': payment.status,
            'transaction_id': payment.transaction_id
        }, status=status.HTTP_200_OK)
        
    except Payment.DoesNotExist:
        return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Payment completion error: {e}")
        return Response({'error': 'Failed to complete payment'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def payment_history(request):
    """Get payment history for the authenticated user"""
    try:
        payments = Payment.objects.filter(order__user=request.user).order_by('-created_at')
        serializer = PaymentSerializer(payments, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Payment history error: {e}")
        return Response({'error': 'Failed to load payment history'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
