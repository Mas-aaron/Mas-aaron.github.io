from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views
from rest_framework.routers import DefaultRouter
from .views import (
    RemoveFromCartView, UpdateCartItemView,
    SendTemplateNotificationView,
    RestaurantViewSet,
    CartItemViewSet,
    OrderDetailView,
    OrderUpdateStatusView,
    AvailableOrderListView,
    MessageViewSet,
    NotificationViewSet,
    RestaurantOrderViewSet,
    CurrentUserView,
    RestaurantProfileView,
    RestaurantSignUpView,
    OrderListCreateView,
    MenuItemListByRestaurantView,
    CreateUserView,
    DashboardAnalyticsView,
    DashboardMenuView,

    RiderOrderViewSet,
    RiderSignUpView,
    ModifierGroupViewSet,

    DirectionsProxyView,
    DietaryPreferenceViewSet,
    UserAddressViewSet,
    CustomerProfileView,
    ReviewViewSet,
    DeviceViewSet,
    test_notification
)
from rest_framework.authtoken.views import obtain_auth_token

# Define custom URL patterns first to ensure they are matched before the router's generic URLs.
custom_router = DefaultRouter()
custom_router.register(r'menu-categories', views.MenuCategoryViewSet, basename='menucategory')

custom_urlpatterns = [
    
    # Cart URLs
    path('cart/', views.CartDetailView.as_view(), name='cart-detail'),
    path('cart/add/', views.AddToCartView.as_view(), name='cart-add-item'),
    path('cart/remove/', RemoveFromCartView.as_view(), name='remove-from-cart'),
    path('cart/update/<int:item_id>/', UpdateCartItemView.as_view(), name='update-cart-item'),

    # Order URLs
    path('orders/', OrderListCreateView.as_view(), name='order-list-create'),
    # path('orders/<int:pk>/', OrderDetailView.as_view(), name='order-detail'),
    path('orders/<int:pk>/update-status/', OrderUpdateStatusView.as_view(), name='order-update-status'),

    # Restaurant URLs
    path('restaurants/<int:restaurant_pk>/menu-items/', MenuItemListByRestaurantView.as_view(), name='restaurant-menu-items'),

    # Auth URLs
    path('register/', CreateUserView.as_view(), name='register'),
    path('register/restaurant/', RestaurantSignUpView.as_view(), name='restaurant-signup'),
    path('login/', obtain_auth_token, name='login'),
    path('me/', CurrentUserView.as_view(), name='current-user'),
    path('profile/restaurant/', RestaurantProfileView.as_view(), name='restaurant-profile'),
    path('profile/customer/', views.CustomerProfileView.as_view(), name='customer-profile'),
    path('devices/unregister/', views.DeviceViewSet.as_view({'post': 'unregister'}), name='device-unregister'),

    # Rider URLs
    path('rider/available-orders/', AvailableOrderListView.as_view(), name='available-orders-list'),
    path('rider/signup/', RiderSignUpView.as_view(), name='rider-signup'),

    # Dashboard URLs
    path('restaurants/dashboard-menu/', views.DashboardMenuView.as_view(), name='dashboard-menu'),
    path('dashboard-analytics/', DashboardAnalyticsView.as_view(), name='dashboard-analytics'),


    # Proxy URLs
    path('directions/', DirectionsProxyView.as_view(), name='directions-proxy'),

    # Test/Debug URLs
    path('test-notification/', views.test_notification, name='test-notification'),
    path('send-template-notification/', SendTemplateNotificationView.as_view(), name='send-template-notification'),

]

# Define and register router viewsets
router = DefaultRouter()
router.register(r'restaurants', RestaurantViewSet, basename='restaurant')
router.register(r'messages', MessageViewSet, basename='message')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'cart-items', CartItemViewSet, basename='cart-item')


router.register(r'restaurant-orders', RestaurantOrderViewSet, basename='restaurant-order')
router.register(r'modifier-groups', ModifierGroupViewSet, basename='modifier-group')
router.register(r'rider-orders', RiderOrderViewSet, basename='rider-order')
router.register(r'dietary-preferences', DietaryPreferenceViewSet, basename='dietary-preference')
router.register(r'addresses', UserAddressViewSet, basename='address')
router.register(r'reviews', views.ReviewViewSet, basename='review')
router.register(r'devices', DeviceViewSet, basename='device')


# Combine custom patterns with router patterns
urlpatterns = custom_urlpatterns + router.urls + custom_router.urls
