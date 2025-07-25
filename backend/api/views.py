from django.db.models import F, FloatField, ExpressionWrapper
from django.db.models.functions import Radians, Power, Sin, Cos, Sqrt, ATan2
from django.shortcuts import get_object_or_404
from rest_framework import viewsets, generics, status
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth.models import User
from .models import Restaurant, MenuCategory, MenuItem, Cart, CartItem, Order, OrderItem, ModifierGroup, Modifier
from .dispatch_service import find_and_assign_rider
from .serializers import (
    RestaurantSerializer, UserSerializer, MenuCategorySerializer, 
    CartSerializer, CartItemSerializer, OrderSerializer, CartItemWriteSerializer, MenuItemSerializer,
    ModifierGroupSerializer, ModifierSerializer, MenuItemBulkUploadSerializer
)

from geopy.distance import geodesic

class RestaurantViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = RestaurantSerializer

    def get_queryset(self):
        queryset = Restaurant.objects.all() # Required for ModelViewSet base name auto-generation
        lat = self.request.query_params.get('lat')
        lng = self.request.query_params.get('lng')

        if lat and lng:
            try:
                lat_f = float(lat)
                lng_f = float(lng)

                # Earth radius in kilometers
                earth_radius_km = 6371.0

                # Haversine formula using Django ORM
                dlat = Radians(F('latitude') - lat_f)
                dlon = Radians(F('longitude') - lng_f)

                a = (
                    Power(Sin(dlat / 2), 2) +
                    Cos(Radians(lat_f)) * Cos(Radians(F('latitude'))) * Power(Sin(dlon / 2), 2)
                )
                c = 2 * ATan2(Sqrt(a), Sqrt(1 - a))
                distance = ExpressionWrapper(
                    earth_radius_km * c,
                    output_field=FloatField()
                )

                queryset = queryset.annotate(distance=distance).order_by('distance')

            except (ValueError, TypeError):
                # Ignore invalid lat/lng and return the default queryset
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
                pass # Ignore invalid lat/lng
        return context

class RestaurantMenuView(generics.ListAPIView):
    serializer_class = MenuCategorySerializer

    def get_queryset(self):
        restaurant_pk = self.kwargs['restaurant_pk']
        return MenuCategory.objects.filter(restaurant_id=restaurant_pk)

class MenuItemListByRestaurantView(generics.ListAPIView):
    serializer_class = MenuItemSerializer

    def get_queryset(self):
        restaurant_pk = self.kwargs['restaurant_pk']
        return MenuItem.objects.filter(category__restaurant_id=restaurant_pk)

class CreateUserView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

class CartView(generics.RetrieveAPIView):
    serializer_class = CartSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        cart, _ = Cart.objects.get_or_create(user=self.request.user)
        return cart

class CartItemViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return CartItemWriteSerializer
        return CartItemSerializer

    def get_queryset(self):
        return CartItem.objects.filter(cart__user=self.request.user).select_related(
            'menu_item__category__restaurant'
        )

    def create(self, request, *args, **kwargs):
        # Use the write serializer to validate and save the data
        write_serializer = self.get_serializer(data=request.data)
        write_serializer.is_valid(raise_exception=True)
        instance, created = write_serializer.save()

        # Use the read serializer to return the full object representation
        read_serializer = CartItemSerializer(instance)

        status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(read_serializer.data, status=status_code)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        # Always return the full CartItem (read serializer)
        read_serializer = CartItemSerializer(instance)
        return Response(read_serializer.data)

    def partial_update(self, request, *args, **kwargs):
        return self.update(request, *args, **kwargs)

class OrderListCreateView(generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        # The serializer's create method now handles all logic, 
        # including validation and associating the user from the request context.
        serializer.save()

class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Ensure users can only see their own orders
        return Order.objects.filter(user=self.request.user)

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

class ModifierViewSet(viewsets.ModelViewSet):
    queryset = Modifier.objects.all()
    serializer_class = ModifierSerializer
    permission_classes = [IsAuthenticated]

class RiderOrderViewSet(viewsets.ReadOnlyModelViewSet):
    """
    This viewset handles listing a rider's assigned orders.
    """
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """
        This view should return a list of all the orders
        assigned to the currently authenticated user (rider).
        """
        return Order.objects.filter(rider=self.request.user).order_by('-created_at')


