from django.db import models
from django.contrib.auth.models import User
from api.models import Order

class LoyaltyTier(models.Model):
    name = models.CharField(max_length=100)  # Bronze, Silver, Gold, Platinum
    points_threshold = models.IntegerField()
    discount_percentage = models.DecimalField(max_digits=5, decimal_places=2)
    benefits = models.TextField()  # Free delivery, priority support, etc.

    def __str__(self):
        return self.name

class CustomerLoyalty(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    points = models.IntegerField(default=0)
    total_points_earned = models.IntegerField(default=0)
    tier = models.ForeignKey(LoyaltyTier, on_delete=models.SET_NULL, null=True, blank=True)
    join_date = models.DateTimeField(auto_now_add=True)
    last_activity = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username}'s Loyalty"

class PointsTransaction(models.Model):
    TRANSACTION_TYPES = (
        ('earn', 'Earn Points'),
        ('redeem', 'Redeem Points'),
        ('expire', 'Points Expired'),
        ('adjust', 'Manual Adjustment'),
    )
    
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    points = models.IntegerField()
    transaction_type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    description = models.TextField()
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.points} points - {self.transaction_type}"

class Reward(models.Model):
    name = models.CharField(max_length=200)
    points_required = models.IntegerField()
    description = models.TextField()
    is_active = models.BooleanField(default=True)
    image = models.ImageField(upload_to='rewards/', null=True, blank=True)
    max_redemptions = models.IntegerField(default=0)  # 0 = unlimited
    redemption_count = models.IntegerField(default=0)

    def __str__(self):
        return self.name

