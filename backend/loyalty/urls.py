from django.urls import path
from .views import LoyaltyProfileView, AvailableRewardsView, RedeemRewardView, TransactionHistoryView

urlpatterns = [
    path('profile/', LoyaltyProfileView.as_view(), name='loyalty-profile'),
    path('rewards/', AvailableRewardsView.as_view(), name='available-rewards'),
    path('redeem/<int:reward_id>/', RedeemRewardView.as_view(), name='redeem-reward'),
    path('transactions/', TransactionHistoryView.as_view(), name='transaction-history'),
]
