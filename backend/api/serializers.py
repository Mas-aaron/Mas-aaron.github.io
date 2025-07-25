import logging
from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Restaurant, MenuCategory, MenuItem, Cart, CartItem, Order, OrderItem, Modifier, ModifierGroup

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


class RestaurantSerializer(serializers.ModelSerializer):
    distance = serializers.FloatField(read_only=True)

    class Meta:
        model = Restaurant
        fields = (
            'id', 'name', 'address', 'phone_number', 'image_url', 
            'latitude', 'longitude', 'distance'
        )

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
    class Meta:
        model = MenuItem
        fields = (
            'id', 'name', 'description', 'price', 'image_url',
            'available_breakfast', 'available_lunch', 'available_dinner',
            'modifier_groups'
        )

class MenuCategorySerializer(serializers.ModelSerializer):
    items = MenuItemSerializer(many=True, read_only=True)

    class Meta:
        model = MenuCategory
        fields = ('id', 'name', 'items')

class CartItemSerializer(serializers.ModelSerializer):
    """Serializer for CartItem model (Read-Only)."""
    menu_item = MenuItemSerializer(read_only=True)
    # Explicitly define menu_item_id to ensure it's in the output for the client.
    menu_item_id = serializers.IntegerField(source='menu_item.id', read_only=True)

    class Meta:
        model = CartItem
        fields = ('id', 'menu_item', 'quantity', 'menu_item_id')


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
        menu_item = validated_data.get('menu_item')
        quantity = validated_data.get('quantity')

        cart_item, created = CartItem.objects.get_or_create(
            cart=cart,
            menu_item=menu_item,
            defaults={'quantity': quantity}
        )

        if not created:
            cart_item.quantity += quantity
            cart_item.save()
        
        # Return a tuple of the instance and a boolean indicating if it was created
        return cart_item, created

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
    menu_item = MenuItemSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = ('id', 'menu_item', 'quantity', 'price')

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    restaurant = RestaurantSerializer(read_only=True)
    restaurant_name = serializers.SerializerMethodField(read_only=True)

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

        restaurant = cart.items.first().menu_item.category.restaurant

        # 2. Validation: Check for missing restaurant location data
        if restaurant.latitude is None or restaurant.longitude is None:
            raise serializers.ValidationError(f"Restaurant '{restaurant.name}' is missing location data and cannot accept orders.")

        total_price = sum(item.menu_item.price * item.quantity for item in cart.items.all())

        # Placeholder for customer coordinates
        customer_lat_placeholder = 37.7749
        customer_lng_placeholder = -122.4194

        # 3. Create the Order
        order = Order.objects.create(
            user=user,
            restaurant=restaurant,
            total_price=total_price,
            delivery_address=validated_data['delivery_address'],
            restaurant_lat=restaurant.latitude,
            restaurant_lng=restaurant.longitude,
            customer_lat=customer_lat_placeholder,
            customer_lng=customer_lng_placeholder
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
            'id', 'user', 'rider', 'restaurant', 'restaurant_name',
            'total_price', 'status', 'created_at', 'delivery_address', 'items',
            'restaurant_lat', 'restaurant_lng', 'customer_lat', 'customer_lng'
        ]
        read_only_fields = ('user', 'rider', 'total_price', 'status', 'created_at', 'items')

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
