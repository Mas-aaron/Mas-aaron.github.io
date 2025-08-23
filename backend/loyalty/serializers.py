from rest_framework import serializers
from .models import LoyaltyTier, CustomerLoyalty, PointsTransaction, Reward

class LoyaltyTierSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoyaltyTier
        fields = '__all__'

class CustomerLoyaltySerializer(serializers.ModelSerializer):
    tier = LoyaltyTierSerializer()

    class Meta:
        model = CustomerLoyalty
        fields = ['points', 'total_points_earned', 'tier', 'join_date']

class PointsTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PointsTransaction
        fields = ['points', 'transaction_type', 'description', 'created_at']

class RewardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reward
        fields = ['id', 'name', 'points_required', 'description', 'image']
