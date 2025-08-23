from django.utils import timezone
from datetime import timedelta
import time
from django.db.models import F

from .models import CustomerLoyalty, LoyaltyTier, PointsTransaction, Reward
from api.notifications import send_push_notification

# Placeholder for notification functions that will be implemented later
def send_tier_upgrade_notification(user, new_tier):
    title = 'Tier Upgrade!'
    body = f"Congratulations! You've been upgraded to {new_tier.name} Tier!"
    send_push_notification(user, title, body)

class LoyaltyService:
    @staticmethod
    def calculate_points(order):
        """Calculate points based on order total and bonuses"""
        base_points = int(order.total_price)  # 1 point per currency unit
        
        # Bonus points for specific conditions
        bonuses = {
            'first_order': 100 if order.user.orders.count() == 1 else 0,
            'weekend_order': 50 if order.created_at.weekday() >= 5 else 0,
            'high_value': 100 if order.total_price > 100 else 0,
        }
        
        total_points = base_points + sum(bonuses.values())
        return total_points, bonuses

    @staticmethod
    def award_points(user, points, source, order=None):
        """Award points to user with expiration (1 year)"""
        loyalty, created = CustomerLoyalty.objects.get_or_create(user=user)
        
        # Update points
        loyalty.points += points
        loyalty.total_points_earned += points
        loyalty.save()
        
        # Create transaction record
        expires_at = timezone.now() + timedelta(days=365)
        PointsTransaction.objects.create(
            user=user,
            points=points,
            transaction_type='earn',
            order=order,
            description=f"Points earned from {source}",
            expires_at=expires_at
        )
        
        # Check for tier upgrade
        LoyaltyService.check_tier_upgrade(user)

    @staticmethod
    def check_tier_upgrade(user):
        loyalty = CustomerLoyalty.objects.get(user=user)
        new_tier = LoyaltyTier.objects.filter(
            points_threshold__lte=loyalty.total_points_earned
        ).order_by('-points_threshold').first()
        
        if new_tier and new_tier != loyalty.tier:
            loyalty.tier = new_tier
            loyalty.save()
            # Send tier upgrade notification
            send_tier_upgrade_notification(user, new_tier)

def generate_reward_code(user, reward):
    """Generate unique reward redemption code"""
    return f"RW{user.id:04d}{reward.id:03d}{int(time.time())}"

class RedemptionService:
    @staticmethod
    def get_available_rewards(user):
        try:
            loyalty = CustomerLoyalty.objects.get(user=user)
            return Reward.objects.filter(
                points_required__lte=loyalty.points,
                is_active=True
            ).exclude(
                max_redemptions__gt=0, 
                redemption_count__gte=F('max_redemptions')
            )
        except CustomerLoyalty.DoesNotExist:
            return Reward.objects.none()

    @staticmethod
    def redeem_reward(user, reward_id):
        reward = Reward.objects.get(id=reward_id, is_active=True)
        loyalty = CustomerLoyalty.objects.get(user=user)
        
        if loyalty.points < reward.points_required:
            raise ValueError("Insufficient points")
        
        if reward.max_redemptions > 0 and reward.redemption_count >= reward.max_redemptions:
            raise ValueError("Reward no longer available")
        
        # Deduct points
        loyalty.points -= reward.points_required
        loyalty.save()
        
        # Update reward redemption count
        reward.redemption_count = F('redemption_count') + 1
        reward.save()
        
        # Create transaction
        PointsTransaction.objects.create(
            user=user,
            points=-reward.points_required,
            transaction_type='redeem',
            description=f"Redeemed: {reward.name}"
        )
        
        # Generate reward code
        reward_code = generate_reward_code(user, reward)
        
        return reward_code
