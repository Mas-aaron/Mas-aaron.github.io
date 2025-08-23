from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken.views import obtain_auth_token

from . import views as api_views


# Router for custom viewsets that require specific URL structures
custom_router = DefaultRouter()
custom_router.register(r'menu-categories', api_views.MenuCategoryViewSet, basename='menucategory')

# Main router for standard ModelViewSets
router = DefaultRouter()
router.register(r'menu-items', api_views.MenuItemViewSet, basename='menu-item')
router.register(r'restaurants', api_views.RestaurantViewSet, basename='restaurant')
router.register(r'messages', api_views.MessageViewSet, basename='message')
router.register(r'notifications', api_views.NotificationViewSet, basename='notification')
router.register(r'cart-items', api_views.CartItemViewSet, basename='cart-item')
router.register(r'restaurant-orders', api_views.RestaurantOrderViewSet, basename='restaurant-order')
router.register(r'modifier-groups', api_views.ModifierGroupViewSet, basename='modifier-group')
router.register(r'rider-orders', api_views.RiderOrderViewSet, basename='rider-order')
router.register(r'dietary-preferences', api_views.DietaryPreferenceViewSet, basename='dietary-preference')
router.register(r'addresses', api_views.UserAddressViewSet, basename='address')
router.register(r'devices', api_views.DeviceViewSet, basename='device')

# Review Endpoints
from .views import (
    RestaurantViewSet, MenuItemViewSet, 
    DietaryPreferenceViewSet, CustomerProfileView,
    DashboardAnalyticsView, RiderOrderViewSet,
    DeviceViewSet
)
from .rider_arrival_views import RiderArrivalView, RiderLocationUpdateView
router.register(r'reviews', api_views.ReviewViewSet, basename='review')
router.register(r'bills', api_views.BillViewSet, basename='bill')
router.register(r'restaurant/dashboard-reviews', api_views.RestaurantOrderReviewViewSet, basename='restaurant-dashboard-review')


# Custom URL patterns for non-router views
custom_urlpatterns = [
    # Cart URLs
    path('cart/', api_views.CartDetailView.as_view(), name='cart-detail'),
    path('cart/add/', api_views.AddToCartView.as_view(), name='cart-add-item'),
    path('cart/remove/', api_views.RemoveFromCartView.as_view(), name='remove-from-cart'),
    path('cart/update/<int:item_id>/', api_views.UpdateCartItemView.as_view(), name='update-cart-item'),

    # Order URLs
    path('orders/', api_views.OrderListCreateView.as_view(), name='order-list-create'),
    path('orders/<int:pk>/', api_views.OrderDetailView.as_view(), name='order-detail'),
    path('orders/<int:pk>/update-status/', api_views.OrderUpdateStatusView.as_view(), name='order-update-status'),
    # path('orders/<int:order_id>/notify-arrival/', api_views.NotifyArrivalView.as_view(), name='order-notify-arrival'),

    # Restaurant URLs
    path('restaurants/<int:restaurant_pk>/menu-items/', api_views.MenuItemListByRestaurantView.as_view(), name='restaurant-menu-items'),

    # Auth URLs
    path('register/', api_views.CreateUserView.as_view(), name='register'),
    path('register/restaurant/', api_views.RestaurantSignUpView.as_view(), name='restaurant-signup'),
    path('login/', obtain_auth_token, name='login'),
    path('me/', api_views.CurrentUserView.as_view(), name='current-user'),
    path('profile/restaurant/', api_views.RestaurantProfileView.as_view(), name='restaurant-profile'),
    path('restaurant/reviews/', api_views.RestaurantReviewsView.as_view(), name='restaurant-reviews'),
    path('profile/customer/', api_views.CustomerProfileView.as_view(), name='customer-profile'),
    path('devices/unregister/', api_views.DeviceViewSet.as_view({'post': 'unregister'}), name='device-unregister'),

    # Rider URLs
    path('rider/available-orders/', api_views.AvailableOrderListView.as_view(), name='available-orders-list'),
    path('rider/signup/', api_views.RiderSignUpView.as_view(), name='rider-signup'),
    path('my-reviews/', api_views.MyRiderReviewsView.as_view(), name='my-rider-reviews'),
    
    # Rider Arrival URLs
    path('rider-orders/<int:order_id>/arrival/', RiderArrivalView.as_view(), name='rider-arrival'),
    path('rider-orders/<int:order_id>/location-update/', RiderLocationUpdateView.as_view(), name='rider-location-update'),

    # Dashboard URLs
    path('restaurants/dashboard-menu/', api_views.DashboardMenuView.as_view(), name='dashboard-menu'),
    path('dashboard-analytics/', api_views.DashboardAnalyticsView.as_view(), name='dashboard-analytics'),

    # Proxy URLs
    path('directions/', api_views.DirectionsProxyView.as_view(), name='directions-proxy'),

    # Test/Debug URLs
    path('test-notification/', api_views.test_notification, name='test-notification'),
    path('send-template-notification/', api_views.SendTemplateNotificationView.as_view(), name='send-template-notification'),
]

# Combine all URL patterns
urlpatterns = custom_urlpatterns + router.urls + custom_router.urls
