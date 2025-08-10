from django.urls import path, include
from rest_framework.routers import DefaultRouter
from ..views.reviews import OrderReviewViewSet, RiderReviewViewSet

router = DefaultRouter()
router.register(r'order-reviews', OrderReviewViewSet, basename='order-review')
router.register(r'rider-reviews', RiderReviewViewSet, basename='rider-review')

urlpatterns = [
    path('', include(router.urls)),
]
