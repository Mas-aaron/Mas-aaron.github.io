import logging
from rest_framework import serializers
from rest_framework.validators import UniqueValidator
from django.contrib.auth.models import User, Group
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import (
    RiderProfile,
    Bill,
    Restaurant, MenuCategory, MenuItem, ModifierGroup, Modifier, Cart, CartItem, Order, OrderItem, 
    Message, Notification, DietaryPreference, CustomerProfile, UserAddress, Review, Device
)
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
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url  # Fallback to relative URL
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
        
        # The UserSerializer's create method will handle user creation and validation.
        user = User.objects.create_user(
            username=owner_data['username'],
            email=owner_data['email'],
            password=owner_data['password']
        )
        Cart.objects.create(user=user)

        # Now create the restaurant and link it to the owner.
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
    modifier_groups = ModifierGroupSerializer(many=True, read_only=True)
    available_breakfast = serializers.BooleanField()
    available_lunch = serializers.BooleanField()
    available_dinner = serializers.BooleanField()
    image = serializers.ImageField(required=False, allow_null=True)
    category = serializers.PrimaryKeyRelatedField(queryset=MenuCategory.objects.all(), required=True)
    restaurant = serializers.ReadOnlyField(source='category.restaurant.id')

    class Meta:
        model = MenuItem
        fields = (
            'id', 'category', 'restaurant', 'name', 'description', 'price', 'image',
            'available_breakfast', 'available_lunch', 'available_dinner',
            'modifier_groups'
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

    class Meta:
        model = Order
        fields = ('id', 'items', 'total_price', 'status', 'created_at', 'delivery_address', 'restaurant_name', 'rider_id')

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


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    restaurant = RestaurantSerializer(read_only=True)
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

        # 2. Validation: Check for required location data
        if 'customer_lat' not in validated_data or 'customer_lng' not in validated_data:
            raise serializers.ValidationError("Customer location (lat, lng) is required.")

        onboarding_restaurant = cart.items.first().menu_item.category.restaurant

        # 3. Validation: Check for missing restaurant location data
        if onboarding_restaurant.latitude is None or onboarding_restaurant.longitude is None:
            raise serializers.ValidationError(f"Restaurant '{onboarding_restaurant.name}' is missing location data and cannot accept orders.")

        # Find the corresponding api.models.Restaurant instance
        try:
            api_restaurant = Restaurant.objects.get(name=onboarding_restaurant.name)
        except Restaurant.DoesNotExist:
            raise serializers.ValidationError(f"Could not find a corresponding active restaurant for '{onboarding_restaurant.name}'.")


        total_price = sum(item.menu_item.price * item.quantity for item in cart.items.all())

        # 4. Create the Order
        order = Order.objects.create(
            user=user,
            restaurant=api_restaurant,
            total_price=total_price,
            delivery_address=validated_data['delivery_address'],
            restaurant_lat=onboarding_restaurant.latitude,
            restaurant_lng=onboarding_restaurant.longitude,
            customer_lat=validated_data['customer_lat'],
            customer_lng=validated_data['customer_lng']
        )

        # 4. Create OrderItems from CartItems
        for cart_item in cart.items.all():
            OrderItem.objects.create(
                order=order,
                menu_item=cart_item.menu_item,
                quantity=cart_item.quantity,
                price=cart_item.menu_item.price
            )
        
        # 5. Clear the cart
        cart.items.all().delete()



        return order

    class Meta:
        model = Order
        fields = [
            'id', 'user', 'rider_id', 'restaurant', 'restaurant_name',
            'total_price', 'status', 'created_at', 'delivery_address', 'items',
            'restaurant_lat', 'restaurant_lng', 'customer_lat', 'customer_lng', 'review'
        ]
        read_only_fields = ('user', 'rider_id', 'restaurant', 'restaurant_name', 'total_price', 'status', 'created_at', 'items')


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
