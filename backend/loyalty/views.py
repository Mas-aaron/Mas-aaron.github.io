from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from .models import CustomerLoyalty, LoyaltyTier, PointsTransaction, Reward
from .serializers import CustomerLoyaltySerializer, RewardSerializer, PointsTransactionSerializer
from .services import RedemptionService

class LoyaltyProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        loyalty, created = CustomerLoyalty.objects.get_or_create(user=request.user)
        next_tier = LoyaltyTier.objects.filter(
            points_threshold__gt=loyalty.total_points_earned
        ).order_by('points_threshold').first()
        
        progress = 0
        if next_tier:
            progress = (loyalty.total_points_earned / next_tier.points_threshold) * 100
        
        data = {
            'points': loyalty.points,
            'total_points_earned': loyalty.total_points_earned,
            'tier': loyalty.tier.name if loyalty.tier else 'Bronze',
            'next_tier': next_tier.name if next_tier else None,
            'progress': min(progress, 100),
            'benefits': loyalty.tier.benefits if loyalty.tier else ''
        }
        return Response(data)

class AvailableRewardsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rewards = RedemptionService.get_available_rewards(request.user)
        serializer = RewardSerializer(rewards, many=True)
        return Response(serializer.data)

class RedeemRewardView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, reward_id):
        try:
            reward_code = RedemptionService.redeem_reward(request.user, reward_id)
            return Response({'reward_code': reward_code, 'message': 'Reward redeemed successfully!'})
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class TransactionHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        transactions = PointsTransaction.objects.filter(user=request.user).order_by('-created_at')[:20]
        serializer = PointsTransactionSerializer(transactions, many=True)
        return Response(serializer.data)

