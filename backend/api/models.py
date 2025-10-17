from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from model_utils.tracker import FieldTracker

from django.conf import settings


class Bill(models.Model):
    restaurant = models.ForeignKey('Restaurant', on_delete=models.CASCADE, related_name='bills')
    amount = models.DecimalField(max_digits=10, decimal_places=2, help_text="The total amount of the bill.")
    status = models.CharField(max_length=20, choices=[('pending', 'Pending'), ('paid', 'Paid')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f'Bill {self.id} for {self.restaurant.name} - {self.status}'


class PaymentPeriod(models.Model):
    """Weekly or daily payment periods for restaurants"""
    PERIOD_TYPES = [
        ('weekly', 'Weekly'),
        ('daily', 'Daily'),
    ]
    
    restaurant = models.ForeignKey('Restaurant', on_delete=models.CASCADE, related_name='payment_periods')
    period_type = models.CharField(max_length=10, choices=PERIOD_TYPES, default='weekly')
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    total_orders = models.IntegerField(default=0)
    gross_revenue = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    platform_fee = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    delivery_fee = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    adjustments = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    net_payout = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    status = models.CharField(max_length=20, choices=[('pending', 'Pending'), ('paid', 'Paid'), ('processing', 'Processing')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        unique_together = ['restaurant', 'start_date', 'end_date', 'period_type']
        ordering = ['-start_date']
    
    def __str__(self):
        return f'{self.period_type.title()} payment for {self.restaurant.name} ({self.start_date.date()} - {self.end_date.date()})'


class OrderPayment(models.Model):
    """Detailed payment breakdown for each order"""
    order = models.OneToOneField('Order', on_delete=models.CASCADE, related_name='payment_details')
    payment_period = models.ForeignKey(PaymentPeriod, on_delete=models.CASCADE, related_name='order_payments')
    
    # Order details
    order_number = models.CharField(max_length=50)
    order_date = models.DateTimeField()
    customer_name = models.CharField(max_length=255)
    
    # Financial breakdown
    subtotal = models.DecimalField(max_digits=10, decimal_places=2)
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    service_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    platform_commission = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    tax_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    tip_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    adjustments = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    net_payout = models.DecimalField(max_digits=10, decimal_places=2)
    
    # Payment status
    payment_status = models.CharField(max_length=20, choices=[('pending', 'Pending'), ('paid', 'Paid'), ('disputed', 'Disputed')], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-order_date']
    
    def __str__(self):
        return f'Payment for Order #{self.order_number}'


class BankAccount(models.Model):
    """Restaurant bank account information for payments"""
    restaurant = models.OneToOneField('Restaurant', on_delete=models.CASCADE, related_name='bank_account')
    account_holder_name = models.CharField(max_length=255)
    bank_name = models.CharField(max_length=255)
    account_number = models.CharField(max_length=50)
    routing_number = models.CharField(max_length=50, blank=True, null=True)
    swift_code = models.CharField(max_length=20, blank=True, null=True)
    account_type = models.CharField(max_length=20, choices=[('checking', 'Checking'), ('savings', 'Savings')], default='checking')
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f'Bank account for {self.restaurant.name}'


class PaymentDispute(models.Model):
    """Customer refund disputes that restaurants can manage"""
    DISPUTE_TYPES = [
        ('refund', 'Customer Refund'),
        ('chargeback', 'Chargeback'),
        ('quality', 'Quality Issue'),
        ('delivery', 'Delivery Issue'),
        ('other', 'Other'),
    ]
    
    DISPUTE_STATUS = [
        ('open', 'Open'),
        ('under_review', 'Under Review'),
        ('resolved', 'Resolved'),
        ('rejected', 'Rejected'),
    ]
    
    order_payment = models.ForeignKey(OrderPayment, on_delete=models.CASCADE, related_name='disputes')
    dispute_type = models.CharField(max_length=20, choices=DISPUTE_TYPES)
    reason = models.TextField()
    amount_disputed = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=DISPUTE_STATUS, default='open')
    restaurant_response = models.TextField(blank=True, null=True)
    resolution_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f'Dispute for Order #{self.order_payment.order_number} - {self.dispute_type}'


class NotificationTemplate(models.Model):
    CATEGORY_CHOICES = [
        ('INFORMATIONAL', 'Informational'),
        ('REMINDER', 'Reminder'),
        ('PROMOTIONAL', 'Promotional'),
        ('PERSONALIZED', 'Personalized'),
        ('TRANSACTIONAL', 'Transactional'),
        ('ENGAGEMENT', 'Engagement'),
    ]

    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    name = models.CharField(max_length=100, unique=True, help_text="A unique name for internal reference, e.g., 'promo_flash_sale'")
    title = models.CharField(max_length=255, help_text="The notification title, can include emojis.")
    body = models.TextField(help_text="The main content of the notification.")
    image_url = models.URLField(max_length=500, blank=True, null=True, help_text="Optional URL for a rich notification image.")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"[{self.get_category_display()}] {self.name}"
from django.core.validators import MaxValueValidator, MinValueValidator

class Restaurant(models.Model):
    class OrderProtocol(models.TextChoices):
        TABLET = 'TABLET', 'Tablet'
        EMAIL = 'EMAIL', 'Email'
        PHONE = 'PHONE', 'Phone Call'

    # Fields from original api.Restaurant
    name = models.CharField(max_length=255)
    address = models.CharField(max_length=255)
    phone_number = models.CharField(max_length=20)
    image = models.ImageField(upload_to='restaurants/', blank=True, null=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    # Merged fields from restaurant_onboarding.Restaurant
    owner = models.OneToOneField(User, on_delete=models.CASCADE, null=True, blank=True, related_name='restaurant_profile') # Allow null for legacy
    email = models.EmailField(unique=True, null=True, blank=True) # Allow null for legacy
    is_approved = models.BooleanField(default=False)
    order_protocol = models.CharField(
        max_length=10,
        choices=OrderProtocol.choices,
        default=OrderProtocol.TABLET
    )
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True) # Allow null for legacy
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True) # Allow null for legacy

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
    price = models.DecimalField(max_digits=8, decimal_places=2)
    image = models.ImageField(upload_to='menu_images/', null=True, blank=True)
    available_breakfast = models.BooleanField(default=True)
    available_lunch = models.BooleanField(default=True)
    available_dinner = models.BooleanField(default=True)
    # ManyToMany to ModifierGroup (optional/required)
    modifier_groups = models.ManyToManyField('ModifierGroup', blank=True, related_name='menu_items')
    dietary_preferences = models.ManyToManyField('DietaryPreference', blank=True, related_name='menu_items')

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
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='cart')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    notified_at = models.DateTimeField(null=True, blank=True, help_text="Timestamp when the user was notified about the abandoned cart.")

    def __str__(self):
        return f'Cart for {self.user.username}'

class CartItem(models.Model):
    cart = models.ForeignKey(Cart, related_name='items', on_delete=models.CASCADE)
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f'{self.quantity} x {self.menu_item.name}'


class Order(models.Model):
    ORDER_TYPE_CHOICES = (
        ('delivery', 'Delivery'),
        ('pickup', 'Pickup'),
        ('dine_in', 'Dine-in'),
    )

    STATUS_CHOICES = (
        # Restaurant-facing statuses
        ('Pending', 'Pending'),                     # A new order that needs confirmation
        ('Accepted', 'Accepted'),                   # Restaurant has confirmed the order
        ('Rejected', 'Rejected'),                   # Restaurant has rejected the order
        ('Preparing', 'Preparing'),                 # Restaurant is preparing the food
        ('Ready for Pickup', 'Ready for Pickup'),   # Food is ready for a rider
        ('Ready for Dine-in', 'Ready for Dine-in'), # Food is ready for dine-in customer

        # Rider/Customer-facing statuses
        ('Assigned', 'Assigned'),                   # A rider has been assigned
        ('Out for Delivery', 'Out for Delivery'),   # Rider has picked up the order
        ('Rider Arrived', 'Rider Arrived'),         # Rider has arrived at customer location
        ('Delivered', 'Delivered'),                 # Rider has delivered the order
        ('Completed', 'Completed'),                 # Order completed (for dine-in/pickup)
        ('Cancelled', 'Cancelled'),                 # Order was cancelled (by customer or system)
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders')
    rider = models.ForeignKey('RiderProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    order_type = models.CharField(max_length=10, choices=ORDER_TYPE_CHOICES, default='delivery')
    created_at = models.DateTimeField(auto_now_add=True)
    delivery_address = models.CharField(max_length=255, blank=True, null=True)
    scheduled_time = models.DateTimeField(null=True, blank=True)  # For dine-in reservations
    estimated_prep_time = models.IntegerField(default=30)  # Minutes
    table_number = models.CharField(max_length=10, blank=True, null=True)  # For dine-in
    tip_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    # Geolocation fields
    restaurant_lat = models.FloatField(null=True, blank=True)
    restaurant_lng = models.FloatField(null=True, blank=True)
    customer_lat = models.FloatField(null=True, blank=True)
    customer_lng = models.FloatField(null=True, blank=True)
    is_billed = models.BooleanField(default=False)
    tracker = FieldTracker()

    def __str__(self):
        return f'Order {self.id} by {self.user.username}'

@receiver(post_save, sender=Order)
def order_status_changed(sender, instance, created, **kwargs):
    # Send notification on order creation OR subsequent status change
    if created or instance.tracker.has_changed('status'):
        from .notifications import send_order_status_notification
        send_order_status_notification(instance)

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
    price = models.DecimalField(max_digits=8, decimal_places=2) # Price at the time of order

    def __str__(self):
        return f'{self.quantity} of {self.menu_item.name}'


class Message(models.Model):
    """Represents a message between a sender and a recipient, optionally tied to an order.""" 
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_messages')
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='received_messages')
    order = models.ForeignKey(Order, on_delete=models.CASCADE, null=True, blank=True, related_name='messages')
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    def __str__(self):
        return f'Message from {self.sender.username} to {self.recipient.username} at {self.timestamp.strftime("%Y-%m-%d %H:%M")}'

    class Meta:
        ordering = ['-timestamp']


class Notification(models.Model):
    """
    Represents a notification for a user.
    e.g., "Your order #12345 has been confirmed."
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    def __str__(self):
        return f'Notification for {self.user.username}: {self.title}'

    class Meta:
        ordering = ['-timestamp']


class DietaryPreference(models.Model):
    """Represents a dietary preference, e.g., Vegetarian, Gluten-Free."""
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name


class CustomerProfile(models.Model):
    """Extends the default User model to include customer-specific information."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='customer_profile')
    dietary_preferences = models.ManyToManyField(DietaryPreference, blank=True)

    def __str__(self):
        return f"Profile for {self.user.username}"


class UserAddress(models.Model):
    """Represents a saved address for a user."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='addresses')
    address_line_1 = models.CharField(max_length=255)
    address_line_2 = models.CharField(max_length=255, blank=True, null=True)
    city = models.CharField(max_length=100)
    state_province = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20)
    country = models.CharField(max_length=100)
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.address_line_1}, {self.city} for {self.user.username}"

    class Meta:
        verbose_name_plural = "User Addresses"


class Device(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='devices')
    token = models.CharField(max_length=255, unique=True)
    device_type = models.CharField(max_length=20, choices=[('android', 'Android'), ('ios', 'iOS')])
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'token')

    def __str__(self):
        return f"{self.user.username}'s {self.device_type} device"


class Review(models.Model):
    """Represents a rating and comment for a specific meal by a user."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews')
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE, related_name='reviews')
    rating = models.PositiveIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'menu_item') # Ensures a user can only review a specific meal once
        ordering = ['-created_at']

    def __str__(self):
        return f'Review for {self.menu_item.name} by {self.user.username}'


class OrderReview(models.Model):
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name='reviews', null=True)
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='review')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    rating = models.DecimalField(max_digits=2, decimal_places=1)
    comment = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    reply_text = models.TextField(blank=True, null=True)
    replied_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f'Review for Order #{self.order.id} by {self.user.username}'




class RiderReview(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='rider_review')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='given_rider_reviews')
    rider = models.ForeignKey(RiderProfile, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviews_received')
    rating = models.DecimalField(max_digits=2, decimal_places=1)
    comment = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Rider Review for Order #{self.order.id} by {self.user.username}'


class OrderActivity(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='activities')
    activity_type = models.CharField(max_length=50)
    description = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.activity_type} for Order #{self.order.id} at {self.created_at}'

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = "Order Activities"


class Payment(models.Model):
    """Model for handling mobile money and other payment methods"""
    PAYMENT_METHODS = [
        ('cash_on_delivery', 'Cash on Delivery'),
        ('mtn_mobile_money', 'MTN Mobile Money'),
        ('airtel_money', 'Airtel Money'),
        ('pesapal', 'Pesapal Payment'),
    ]
    
    PAYMENT_STATUS = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]
    
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='payment')
    method = models.CharField(max_length=20, choices=PAYMENT_METHODS, default='cash_on_delivery')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=15, choices=PAYMENT_STATUS, default='pending')
    
    # Mobile money specific fields
    phone_number = models.CharField(max_length=20, null=True, blank=True)
    transaction_id = models.CharField(max_length=100, null=True, blank=True)
    reference = models.CharField(max_length=100, null=True, blank=True)
    pesapal_tracking_id = models.CharField(max_length=255, blank=True, null=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Failure reason
    failure_reason = models.TextField(null=True, blank=True)
    
    def __str__(self):
        return f'Payment {self.id} - Order #{self.order.id} - {self.get_method_display()} - {self.status}'
    
    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = "Payments"


