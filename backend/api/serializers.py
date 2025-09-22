import logging
from rest_framework import serializers
from rest_framework.validators import UniqueValidator
from django.contrib.auth.models import User, Group
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import *
from rest_framework.authtoken.models import Token
from .utils import format_ugx_currency
import csv
import io
from .models import OrderReview, RiderReview

logger = logging.getLogger(__name__)

class MenuItemBulkUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
    restaurant_id = serializers.IntegerField()

    def validate(self, data):
        # Optionally validate file type/size here
        return data

    def create(self, validated_data):
        import csv, io
        from .models import MenuCategory, MenuItem
        file = validated_data['file']
        restaurant_id = validated_data['restaurant_id']
        decoded = file.read().decode('utf-8')
        reader = csv.DictReader(io.StringIO(decoded))
        created, updated = 0, 0
        for row in reader:
            # Expected fields: category, name, description, price, image_url, available_breakfast, available_lunch, available_dinner
            category, _ = MenuCategory.objects.get_or_create(
                restaurant_id=restaurant_id, name=row['category'])
            item, was_created = MenuItem.objects.update_or_create(
                category=category,
                name=row['name'],
                defaults={
                    'description': row.get('description', ''),
                    'price': row.get('price', 0.0),
                    'image_url': row.get('image_url', ''),
                    'available_breakfast': row.get('available_breakfast', '1') in ['1', 'true', 'True'],
                    'available_lunch': row.get('available_lunch', '1') in ['1', 'true', 'True'],
                    'available_dinner': row.get('available_dinner', '1') in ['1', 'true', 'True'],
                }
            )
            if was_created:
                created += 1
            else:
                updated += 1
        return {'created': created, 'updated': updated}


class RestaurantProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for the restaurant owner to view and update their profile.
    """
    image = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = Restaurant
        fields = ('id', 'name', 'address', 'phone_number', 'image', 'order_protocol')
        read_only_fields = ('id',)


class RestaurantSerializer(serializers.ModelSerializer):
    distance = serializers.FloatField(read_only=True)
    average_rating = serializers.FloatField(read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Restaurant
        fields = (
            'id', 'name', 'address', 'phone_number', 'image_url', 
            'latitude', 'longitude', 'distance', 'average_rating'
        )

    def get_image_url(self, obj):
        if obj.image and hasattr(obj.image, 'url'):
            # Return the direct URL from the storage backend (GCS or local)
            return obj.image.url
        return None


class UserSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(required=True)
    password2 = serializers.CharField(style={'input_type': 'password'}, write_only=True)

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'password', 'password2')
        extra_kwargs = {
            'password': {'write_only': True}
        }

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("A user with that username already exists.")
        return value

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with that email address already exists.")
        return value

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError({'password': 'Passwords must match.'})
        return data

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        # Automatically create a token for the new user
        Token.objects.create(user=user)
        Cart.objects.create(user=user)
        return user


class RestaurantSignUpSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new Restaurant, including a new User account for the owner.
    """
    owner = UserSerializer()

    class Meta:
        model = Restaurant
        fields = ('id', 'owner', 'name', 'address', 'phone_number', 'email', 'image', 'order_protocol')

    def create(self, validated_data):
        owner_data = validated_data.pop('owner')
        
        # Create the user account
        user = User.objects.create_user(
            username=owner_data['username'],
            email=owner_data['email'],
            password=owner_data['password']
        )
        
        # Create user cart and token
        Cart.objects.create(user=user)
        Token.objects.create(user=user)

        # Now create the restaurant and link it to the owner
        restaurant = Restaurant.objects.create(owner=user, **validated_data)
        
        return restaurant

class ModifierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Modifier
        fields = ('id', 'name', 'price_delta')

class ModifierGroupSerializer(serializers.ModelSerializer):
    modifiers = ModifierSerializer(many=True, read_only=True)
    class Meta:
        model = ModifierGroup
        fields = ('id', 'name', 'required', 'modifiers')

class MenuItemSerializer(serializers.ModelSerializer):
    price = serializers.FloatField()
    price_ugx = serializers.SerializerMethodField()
    modifier_groups = ModifierGroupSerializer(many=True, read_only=True)
    available_breakfast = serializers.BooleanField()
    available_lunch = serializers.BooleanField()
    available_dinner = serializers.BooleanField()
    category = serializers.PrimaryKeyRelatedField(queryset=MenuCategory.objects.all())
    restaurant = RestaurantSerializer(read_only=True)
    image_url = serializers.SerializerMethodField()

    def get_price_ugx(self, obj):
        return format_ugx_currency(obj.price)

    def get_image_url(self, obj):
        if obj.image and hasattr(obj.image, 'url'):
            # Return the URL directly from our custom storage backend
            # This will be a Supabase URL or local URL depending on configuration
            return obj.image.url
        return None


    class Meta:
        model = MenuItem
        fields = (
            'id', 'category', 'restaurant', 'name', 'description', 'price', 'price_ugx', 'image_url',
            'available_breakfast', 'available_lunch', 'available_dinner',
            'modifier_groups', 'image'
        )

class MenuCategoryCRUDSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuCategory
        fields = ('id', 'name')


class MenuCategorySerializer(serializers.ModelSerializer):
    items = MenuItemSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = ('id', 'name', 'items')


class MenuCategoryListSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuCategory
        fields = ('id', 'name')

class CartItemSerializer(serializers.ModelSerializer):
    """Serializer for CartItem model (Read-Only)."""
    menu_item = MenuItemSerializer(read_only=True)
    # Explicitly define menu_item_id to ensure it's in the output for the client.
    menu_item_id = serializers.IntegerField(source='menu_item.id', read_only=True)

    class Meta:
        model = CartItem
        fields = ('id', 'menu_item', 'quantity', 'menu_item_id')


class RestaurantOrderItemSerializer(serializers.ModelSerializer):
    menu_item_name = serializers.CharField(source='menu_item.name')

    class Meta:
        model = OrderItem
        fields = ('menu_item_name', 'quantity', 'price')

class RestaurantOrderSerializer(serializers.ModelSerializer):
    items = RestaurantOrderItemSerializer(many=True, read_only=True)
    total_price = serializers.FloatField()
    total_price_ugx = serializers.SerializerMethodField()

    def get_total_price_ugx(self, obj):
        return format_ugx_currency(obj.total_price)

    class Meta:
        model = Order
        fields = ('id', 'items', 'total_price', 'total_price_ugx', 'status', 'created_at', 'delivery_address', 'restaurant_name', 'rider_id')

class CartItemWriteSerializer(serializers.ModelSerializer):
    """Serializer for writing (create/update) CartItem data."""
    menu_item_id = serializers.PrimaryKeyRelatedField(
        queryset=MenuItem.objects.all(), source='menu_item', write_only=True, required=False
    )

    class Meta:
        model = CartItem
        fields = ('menu_item_id', 'quantity')

    def create(self, validated_data):
        user = self.context['request'].user
        cart, _ = Cart.objects.get_or_create(user=user)
        menu_item = validated_data.pop('menu_item', None)
        if not menu_item:
            raise serializers.ValidationError("A valid 'menu_item_id' is required.")
        quantity = validated_data.get('quantity')

        cart_item, created = CartItem.objects.get_or_create(
            cart=cart,
            menu_item=menu_item,
            defaults={'quantity': quantity}
        )

        if not created:
            cart_item.quantity += quantity
            cart_item.save()

        return cart_item

    def update(self, instance, validated_data):
        # PATCH/PUT should set the quantity to the new value, not increment
        instance.quantity = validated_data.get('quantity', instance.quantity)
        instance.save()
        return instance

class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = Cart
        fields = ('id', 'user', 'items', 'created_at')
        read_only_fields = ('user', 'created_at')

class OrderItemSerializer(serializers.ModelSerializer):
    """Serializer for OrderItem model."""
    menu_item = MenuItemSerializer(read_only=True)
    menu_item_name = serializers.CharField(source='menu_item.name', read_only=True)

    class Meta:
        model = OrderItem
        fields = ('id', 'menu_item', 'menu_item_name', 'quantity', 'price')

class OrderReviewSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = OrderReview
        fields = ['id', 'order', 'user', 'rating', 'comment', 'created_at', 'reply_text', 'replied_at']
        read_only_fields = ['id', 'created_at', 'reply_text', 'replied_at']

    def validate_order(self, value):
        """
        Check that the order is delivered and belongs to the user.
        """
        if value.user != self.context['request'].user:
            raise serializers.ValidationError("You can only review your own orders.")
        if value.status.lower() != 'delivered':
            raise serializers.ValidationError("You can only review delivered orders.")
        if OrderReview.objects.filter(order=value).exists():
            raise serializers.ValidationError("This order has already been reviewed.")
        return value


class RiderPublicProfileSerializer(serializers.ModelSerializer):
    """
    Serializer to expose public details of a rider.
    """
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)

    class Meta:
        model = RiderProfile
        fields = ('first_name', 'last_name')


class CustomerContactSerializer(serializers.ModelSerializer):
    """
    Serializer to expose customer contact details to the rider.
    """
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    phone_number = serializers.CharField(source='customerprofile.phone_number', read_only=True, allow_null=True)

    class Meta:
        model = User
        fields = ('first_name', 'last_name', 'phone_number')


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    restaurant = RestaurantSerializer(read_only=True)
    rider = RiderPublicProfileSerializer(read_only=True)
    review = serializers.SerializerMethodField()
    restaurant_name = serializers.SerializerMethodField(read_only=True)

    def get_review(self, obj):
        if hasattr(obj, 'review'):
            return OrderReviewSerializer(obj.review).data
        return None

    def get_restaurant_name(self, obj):
        if obj.restaurant:
            return obj.restaurant.name
        return None

    def create(self, validated_data):
        user = self.context['request'].user
        cart = getattr(user, 'cart', None)

        # 1. Validation: Check for an empty cart
        if not cart or not cart.items.exists():
            raise serializers.ValidationError("Your cart is empty.")

        # 2. Validation: Check for required location data (only for delivery orders)
        order_type = validated_data.get('order_type', 'delivery')
        if order_type == 'delivery':
            if 'customer_lat' not in validated_data or 'customer_lng' not in validated_data:
                raise serializers.ValidationError("Customer location (lat, lng) is required for delivery orders.")
            if validated_data.get('customer_lat') is None or validated_data.get('customer_lng') is None:
                raise serializers.ValidationError("Customer location (lat, lng) is required for delivery orders.")

        # 3. Validation: Ensure all items in cart are from the same restaurant
        restaurants = set()
        for cart_item in cart.items.all():
            restaurants.add(cart_item.menu_item.category.restaurant.id)
        
        if len(restaurants) > 1:
            raise serializers.ValidationError("Your cart contains items from multiple restaurants. Please order from one restaurant at a time.")

        onboarding_restaurant = cart.items.first().menu_item.category.restaurant

        # 3. Validation: Check for missing restaurant location data
        if onboarding_restaurant.latitude is None or onboarding_restaurant.longitude is None:
            raise serializers.ValidationError(f"Restaurant '{onboarding_restaurant.name}' is missing location data and cannot accept orders.")

        # Find the corresponding api.models.Restaurant instance
        try:
            # Use ID instead of name to ensure we get the exact restaurant
            api_restaurant = Restaurant.objects.get(id=onboarding_restaurant.id)
        except Restaurant.DoesNotExist:
            raise serializers.ValidationError(f"Could not find a corresponding active restaurant for '{onboarding_restaurant.name}'.")


        total_price = sum(item.menu_item.price * item.quantity for item in cart.items.all())

        # 4. Create the Order
        order = Order.objects.create(
            user=user,
            restaurant=api_restaurant,
            total_price=total_price,
            order_type=validated_data.get('order_type', 'delivery'),
            delivery_address=validated_data.get('delivery_address', ''),
            scheduled_time=validated_data.get('scheduled_time'),
            tip_amount=validated_data.get('tip_amount', 0.00),
            restaurant_lat=onboarding_restaurant.latitude,
            restaurant_lng=onboarding_restaurant.longitude,
            customer_lat=validated_data.get('customer_lat'),
            customer_lng=validated_data.get('customer_lng')
        )

        # 4. Create OrderItems from CartItems
        for cart_item in cart.items.all():
            OrderItem.objects.create(
                order=order,
                menu_item=cart_item.menu_item,
                quantity=cart_item.quantity,
                price=cart_item.menu_item.price
            )
        
        # 5. Calculate estimated preparation time
        order.estimated_prep_time = self._calculate_prep_time(cart.items.all())
        order.save()
        
        # 6. Clear the cart
        cart.items.all().delete()

        return order

    def _calculate_prep_time(self, cart_items):
        """Calculate estimated preparation time in minutes based on order complexity."""
        base_time = 15  # Base preparation time in minutes
        item_time = 0
        
        for cart_item in cart_items:
            # Add time based on quantity (2 minutes per additional item)
            item_time += (cart_item.quantity - 1) * 2
            
            # Add complexity time based on menu item category or type
            menu_item = cart_item.menu_item
            if hasattr(menu_item, 'category') and menu_item.category:
                category_name = menu_item.category.name.lower()
                if 'pizza' in category_name or 'grill' in category_name:
                    item_time += 10  # Complex items take longer
                elif 'salad' in category_name or 'drink' in category_name:
                    item_time += 2   # Simple items are quick
                else:
                    item_time += 5   # Standard items
            else:
                item_time += 5  # Default time for items without category
        
        total_time = base_time + item_time
        
        # Cap the maximum preparation time at 60 minutes
        return min(total_time, 60)

    total_price_ugx = serializers.SerializerMethodField()

    def get_total_price_ugx(self, obj):
        return format_ugx_currency(obj.total_price)

    class Meta:
        model = Order
        fields = [
            'id', 'user', 'rider', 'restaurant', 'restaurant_name',
            'total_price', 'total_price_ugx', 'status', 'created_at', 'delivery_address', 'items',
            'customer_lat', 'customer_lng', 'restaurant_lat', 'restaurant_lng', 'review',
            'order_type', 'scheduled_time', 'tip_amount', 'table_number', 'estimated_prep_time'
        ]
        read_only_fields = ('user', 'rider', 'restaurant', 'restaurant_name', 'total_price', 'status', 'created_at', 'items')


class RiderNotificationOrderSerializer(serializers.ModelSerializer):
    """A simplified order serializer for rider notifications."""
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    restaurant_address = serializers.CharField(source='restaurant.address', read_only=True)

    class Meta:
        model = Order
        fields = ('id', 'restaurant_name', 'restaurant_address', 'delivery_address', 'total_price', 'created_at')


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email')


class RestaurantOrderSerializer(OrderSerializer):
    """An order serializer specifically for the restaurant view, including customer details."""
    user = CustomerSerializer(read_only=True)


class RiderOrderSerializer(OrderSerializer):
    """An order serializer for the rider view, including customer contact details."""
    customer = CustomerContactSerializer(source='user', read_only=True)

    class Meta(OrderSerializer.Meta):
        fields = OrderSerializer.Meta.fields + ['customer']
        read_only_fields = OrderSerializer.Meta.read_only_fields


class OrderUpdateStatusSerializer(serializers.ModelSerializer):
    """
    Serializer for updating only the status of an order.
    """
    status = serializers.ChoiceField(choices=Order.STATUS_CHOICES)

    class Meta:
        model = Order
        fields = ['status']

    def update(self, instance, validated_data):
        # First, update the order status as usual
        instance = super().update(instance, validated_data)

        # Check if the new status is 'Ready for Pickup'
        if instance.status == 'ready_for_pickup':
            logger.info(f"Order {instance.id} is now 'Ready for Pickup'. Sending notification to riders.")
            try:
                channel_layer = get_channel_layer()
                if channel_layer is not None:
                    order_data = RiderNotificationOrderSerializer(instance).data
                    async_to_sync(channel_layer.group_send)(
                        'riders',
                        {
                            'type': 'new.order',
                            'order': order_data
                        }
                    )
                    logger.info(f"Successfully sent notification for order {instance.id} to 'riders' group.")
            except Exception as e:
                logger.error(f"Failed to send 'Ready for Pickup' notification for order {instance.id}: {e}")
        
        return instance


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for the Notification model."""
    class Meta:
        model = Notification
        fields = ('id', 'user', 'title', 'message', 'timestamp', 'is_read')
        read_only_fields = ('id', 'user', 'title', 'message', 'timestamp')


class MessageSerializer(serializers.ModelSerializer):
    """Serializer for the Message model."""
    sender = CustomerSerializer(read_only=True)
    recipient = CustomerSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ('id', 'sender', 'recipient', 'order', 'content', 'timestamp', 'is_read')
        read_only_fields = ('id', 'sender', 'timestamp')


class DeviceSerializer(serializers.ModelSerializer):
    """Serializer for the Device model."""
    # By explicitly defining the token field here, we override the default
    # which includes a UniqueValidator. This allows our custom view logic
    # in DeviceViewSet to handle the creation/update idempotently without the
    # serializer raising a premature validation error.
    token = serializers.CharField(validators=[])

    class Meta:
        model = Device
        fields = ('id', 'token', 'device_type', 'created_at')
        read_only_fields = ('user',)


class RiderSignUpSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(
        required=True,
        validators=[UniqueValidator(queryset=User.objects.all(), message="A user with this email already exists.")]
    )

    class Meta:
        model = User
        fields = ('email', 'password', 'first_name', 'last_name')

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        try:
            rider_group = Group.objects.get(name='Rider')
            user.groups.add(rider_group)
        except Group.DoesNotExist:
            logger.error("CRITICAL: 'Rider' group not found in database. Rider user was not assigned to the correct group.")
        
        RiderProfile.objects.create(user=user)
        return user


class DietaryPreferenceSerializer(serializers.ModelSerializer):
    """Serializer for dietary preferences."""
    class Meta:
        model = DietaryPreference
        fields = ('id', 'name', 'description')


class UserAddressSerializer(serializers.ModelSerializer):
    """Serializer for user addresses."""
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = UserAddress
        fields = (
            'id', 'user', 'address_line_1', 'address_line_2', 'city',
            'state_province', 'postal_code', 'country', 'is_default'
        )
        read_only_fields = ('id',)


class ReviewSerializer(serializers.ModelSerializer):
    """Serializer for the Review model."""
    user = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = Review
        fields = ('id', 'user', 'menu_item', 'rating', 'comment', 'created_at')
        read_only_fields = ('id', 'user', 'created_at')

    def validate(self, data):
        # Check if the user has actually ordered the item they are reviewing.
        user = self.context['request'].user
        menu_item = data['menu_item']

        has_ordered = Order.objects.filter(
            user=user,
            items__menu_item=menu_item,
            status='Delivered' # Or other statuses that you consider 'reviewable'
        ).exists()

        if not has_ordered:
            raise serializers.ValidationError("You can only review items you have purchased and received.")

        return data


class DeviceSerializer(serializers.ModelSerializer):
    """Serializer for the Device model."""
    # By explicitly defining the token field here, we override the default
    # which includes a UniqueValidator. This allows our custom view logic
    # in DeviceViewSet to handle the creation/update idempotently without the
    # serializer raising a premature validation error.
    token = serializers.CharField(validators=[])

    class Meta:
        model = Device
        fields = ('id', 'token', 'device_type', 'created_at')
        read_only_fields = ('user',)

class CustomerProfileSerializer(serializers.ModelSerializer):
    """Serializer for the customer's profile, including dietary preferences."""
    user = CustomerSerializer(read_only=True)
    dietary_preferences = DietaryPreferenceSerializer(many=True, read_only=True)
    dietary_preference_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        write_only=True,
        queryset=DietaryPreference.objects.all(),
        source='dietary_preferences',
        required=False
    )

    class Meta:
        model = CustomerProfile
        fields = ('user', 'dietary_preferences', 'dietary_preference_ids')


class RestaurantDashboardReviewSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying order reviews on the restaurant dashboard.
    Hides sensitive user information.
    """
    class Meta:
        model = OrderReview
        fields = ['id', 'rating', 'comment', 'created_at']


class RestaurantOrderReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='user.get_full_name', read_only=True)
    order_total = serializers.DecimalField(source='order.total', max_digits=10, decimal_places=2, read_only=True)
    order_items_count = serializers.SerializerMethodField()

    class Meta:
        model = OrderReview
        fields = [
            'id', 'rating', 'comment', 'created_at', 'reply_text', 'replied_at',
            'customer_name', 'order_total', 'order_items_count', 'order'
        ]
        read_only_fields = fields

    def get_order_items_count(self, obj):
        return obj.order.items.count()






class BillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Bill
        fields = '__all__'


class PaymentPeriodSerializer(serializers.ModelSerializer):
    gross_revenue_ugx = serializers.SerializerMethodField()
    net_payout_ugx = serializers.SerializerMethodField()
    platform_fee_ugx = serializers.SerializerMethodField()
    
    class Meta:
        model = PaymentPeriod
        fields = '__all__'
    
    def get_gross_revenue_ugx(self, obj):
        return format_ugx_currency(obj.gross_revenue)
    
    def get_net_payout_ugx(self, obj):
        return format_ugx_currency(obj.net_payout)
    
    def get_platform_fee_ugx(self, obj):
        return format_ugx_currency(obj.platform_fee)


class OrderPaymentSerializer(serializers.ModelSerializer):
    subtotal_ugx = serializers.SerializerMethodField()
    net_payout_ugx = serializers.SerializerMethodField()
    platform_commission_ugx = serializers.SerializerMethodField()
    delivery_fee_ugx = serializers.SerializerMethodField()
    
    class Meta:
        model = OrderPayment
        fields = '__all__'
    
    def get_subtotal_ugx(self, obj):
        return format_ugx_currency(obj.subtotal)
    
    def get_net_payout_ugx(self, obj):
        return format_ugx_currency(obj.net_payout)
    
    def get_platform_commission_ugx(self, obj):
        return format_ugx_currency(obj.platform_commission)
    
    def get_delivery_fee_ugx(self, obj):
        return format_ugx_currency(obj.delivery_fee)


class BankAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = BankAccount
        fields = '__all__'
        extra_kwargs = {
            'account_number': {'write_only': True},
            'routing_number': {'write_only': True},
        }


class PaymentDisputeSerializer(serializers.ModelSerializer):
    amount_disputed_ugx = serializers.SerializerMethodField()
    order_number = serializers.ReadOnlyField(source='order_payment.order_number')
    
    class Meta:
        model = PaymentDispute
        fields = '__all__'
    
    def get_amount_disputed_ugx(self, obj):
        return format_ugx_currency(obj.amount_disputed)

class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = ['token']

class RiderReviewSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())
    rider = serializers.ReadOnlyField(source='rider.id')
    customer_name = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = RiderReview
        fields = ['id', 'order', 'user', 'rider', 'customer_name', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'created_at', 'rider']

    def validate_order(self, value):
        """
        Check that the order is delivered, belongs to the user, and has a rider.
        """
        if value.user != self.context['request'].user:
            raise serializers.ValidationError("You can only review riders for your own orders.")
        if value.status.lower() != 'delivered':
            raise serializers.ValidationError("You can only review riders for delivered orders.")
        if not hasattr(value, 'rider') or value.rider is None:
             raise serializers.ValidationError("This order does not have a rider to review.")
        if RiderReview.objects.filter(order=value).exists():
            raise serializers.ValidationError("The rider for this order has already been reviewed.")
        return value

    def create(self, validated_data):
        order = validated_data['order']
        rider = order.rider
        review = RiderReview.objects.create(rider=rider, **validated_data)
        return review
