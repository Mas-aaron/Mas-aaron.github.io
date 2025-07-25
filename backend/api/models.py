from django.db import models
from django.contrib.auth.models import User

class Restaurant(models.Model):
    name = models.CharField(max_length=255)
    address = models.CharField(max_length=255)
    phone_number = models.CharField(max_length=20)
    image_url = models.URLField(max_length=200, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    def __str__(self):
        return self.name


class MenuCategory(models.Model):
    restaurant = models.ForeignKey(Restaurant, related_name='categories', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)

    class Meta:
        verbose_name_plural = "Menu Categories"

    def __str__(self):
        return self.name


class MenuItem(models.Model):
    category = models.ForeignKey(MenuCategory, related_name='items', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    description = models.TextField()
    price = models.DecimalField(max_digits=6, decimal_places=2)
    image_url = models.URLField(max_length=200, blank=True, null=True)
    available_breakfast = models.BooleanField(default=True)
    available_lunch = models.BooleanField(default=True)
    available_dinner = models.BooleanField(default=True)
    # ManyToMany to ModifierGroup (optional/required)
    modifier_groups = models.ManyToManyField('ModifierGroup', blank=True, related_name='menu_items')

    def __str__(self):
        return self.name

class ModifierGroup(models.Model):
    name = models.CharField(max_length=100)
    required = models.BooleanField(default=False)
    # e.g. 'Spice Level', 'Add-ons'

    def __str__(self):
        return f"{self.name} ({'Required' if self.required else 'Optional'})"

class Modifier(models.Model):
    group = models.ForeignKey(ModifierGroup, related_name='modifiers', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    price_delta = models.DecimalField(max_digits=6, decimal_places=2, default=0.0)
    # e.g. 'Mild', 'Extra Cheese'

    def __str__(self):
        return f"{self.name} (+{self.price_delta})"


class Cart(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Cart for {self.user.username}'

class CartItem(models.Model):
    cart = models.ForeignKey(Cart, related_name='items', on_delete=models.CASCADE)
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f'{self.quantity} x {self.menu_item.name}'


class Order(models.Model):
    STATUS_CHOICES = (
        ('Pending', 'Pending'),                 # Customer has placed the order
        ('Preparing', 'Preparing'),             # Restaurant is preparing the food
        ('Ready for Pickup', 'Ready for Pickup'), # Food is ready, waiting for a rider
        ('Accepted', 'Accepted'),               # Rider has accepted the order
        ('Out for Delivery', 'Out for Delivery'), # Rider has picked up the order
        ('Delivered', 'Delivered'),             # Rider has delivered the order
        ('Cancelled', 'Cancelled'),             # Order was cancelled
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders')
    rider = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_orders')
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Ready for Pickup')
    created_at = models.DateTimeField(auto_now_add=True)
    delivery_address = models.CharField(max_length=255)
    # Geolocation fields
    restaurant_lat = models.FloatField(null=True, blank=True)
    restaurant_lng = models.FloatField(null=True, blank=True)
    customer_lat = models.FloatField(null=True, blank=True)
    customer_lng = models.FloatField(null=True, blank=True)

    def __str__(self):
        return f'Order {self.id} by {self.user.username}'

class RiderProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='rider_profile')
    is_available = models.BooleanField(default=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    def __str__(self):
        return f'Profile for rider {self.user.username}'


class OrderItem(models.Model):
    order = models.ForeignKey(Order, related_name='items', on_delete=models.CASCADE)
    menu_item = models.ForeignKey(MenuItem, on_delete=models.PROTECT) # Protect so we don't lose order history
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=6, decimal_places=2) # Price at the time of order

    def __str__(self):
        return f'{self.quantity} of {self.menu_item.name}'

