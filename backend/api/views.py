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
    
    result = {
        'status': 'testing',
        'credentials_available': False,
        'bucket_accessible': False,
        'upload_test': False,
        'objects_in_bucket': 0,
        'errors': []
    }
    
    try:
        # Check if credentials are available
        credentials_json = os.getenv('GOOGLE_APPLICATION_CREDENTIALS_JSON')
        if not credentials_json:
            result['errors'].append('GOOGLE_APPLICATION_CREDENTIALS_JSON not found in environment')
            return JsonResponse(result)
        
        result['credentials_available'] = True
        
        # Parse credentials
        credentials_info = json.loads(credentials_json)
        project_id = credentials_info.get('project_id')
        
        # Create temporary credential file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_file:
            json.dump(credentials_info, temp_file)
            temp_file.flush()
            temp_cred_path = temp_file.name
        
        # Initialize client
        from google.oauth2 import service_account
        from google.cloud import storage
        credentials = service_account.Credentials.from_service_account_file(temp_cred_path)
        client = storage.Client(credentials=credentials, project=project_id)
        
        bucket_name = 'storage-bucket-fortexpress'
        bucket = client.bucket(bucket_name)
        
        # Test bucket access
        if bucket.exists():
            result['bucket_accessible'] = True
            
            # Count objects in bucket
            blobs = list(bucket.list_blobs(max_results=100))
            result['objects_in_bucket'] = len(blobs)
            result['object_names'] = [blob.name for blob in blobs[:10]]  # First 10 objects
            
            # Test upload
            try:
                test_content = b"Test file content for GCS upload"
                blob_name = "test_uploads/connection_test.txt"
                
                blob = bucket.blob(blob_name)
                blob.upload_from_string(test_content, content_type='text/plain')
                
                # Try to make it public
                try:
                    blob.acl.all().grant_read()
                    blob.acl.save()
                except Exception as acl_error:
                    result['errors'].append(f'ACL error: {str(acl_error)}')
                
                result['upload_test'] = True
                result['test_file_url'] = f"https://storage.googleapis.com/{bucket_name}/{blob_name}"
                
            except Exception as upload_error:
                result['errors'].append(f'Upload error: {str(upload_error)}')
        else:
            result['errors'].append(f'Bucket {bucket_name} does not exist or is not accessible')
        
        # Clean up temp file
        os.unlink(temp_cred_path)
        
        result['status'] = 'completed'
        
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
    UserAddress, Review, Device, RiderProfile, NotificationTemplate, OrderReview, RiderReview, PaymentPeriod, BankAccount, PaymentDispute
)
from .dispatch_service import find_and_assign_rider
from loyalty.services import LoyaltyService
from .serializers import (
    UserSerializer,
    RestaurantSerializer,
    MenuItemSerializer,
    CartSerializer,
    CartItemSerializer,
    CartItemWriteSerializer,
    OrderSerializer,
    RestaurantSignUpSerializer,
    RiderSignUpSerializer,
    CustomerProfileSerializer,
    RestaurantProfileSerializer,
    OrderUpdateStatusSerializer,
    RestaurantOrderSerializer,
    RiderOrderSerializer,
    MessageSerializer,
    MenuCategoryCRUDSerializer,
    BillSerializer,
    RestaurantDashboardReviewSerializer,
    DietaryPreferenceSerializer,
    UserAddressSerializer,
    ReviewSerializer,
    OrderReviewSerializer,
    RiderReviewSerializer,
    DeviceSerializer,
    RestaurantOrderReviewSerializer,
    MenuItemBulkUploadSerializer,
    ModifierGroupSerializer,
    ModifierSerializer,
    NotificationSerializer,
    PaymentPeriodSerializer,
    OrderPaymentSerializer,
    BankAccountSerializer,
    PaymentDisputeSerializer,
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
                logger.info(f'Sent new order notification for order {order.id} to group restaurant_{restaurant_id}')
        except Exception as e:
            logger.error(f'Failed to send new order notification for order {order.id}: {e}')

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
                except Exception as e:
                    logger.warning(f"Failed to send WebSocket notification for order {order.id}: {e}")
                    # Continue execution - WebSocket failure shouldn't break order updates

                # Specific notification if a rider was just assigned
                if new_status == 'En route to Restaurant' and order.rider:
                    if order.restaurant and order.restaurant.owner:
                        send_push_notification(
                            order.restaurant.owner,
                            f"Rider assigned for order #{order.id}",
                            f"{order.rider.user.username} has accepted the delivery.",
                            data={'orderId': str(order.id), 'status': new_status}
                        )

            # If order is ready, notify available riders via WebSocket and Push Notification
            if new_status == 'Ready for Pickup':
                # 1. Notify via WebSocket (existing functionality)
                channel_layer = get_channel_layer()
                order_serializer = RestaurantOrderSerializer(order)
                async_to_sync(channel_layer.group_send)(
                    'riders_available',
                    {'type': 'new_order_message', 'order': order_serializer.data}
                )
                logger.info(f"Sent 'Ready for Pickup' WebSocket message for order {order.id} to riders_available group.")

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
        today = datetime.now().date()
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
                created_at__gte=datetime.now() - timedelta(days=365)
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
