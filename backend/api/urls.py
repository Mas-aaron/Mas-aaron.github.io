from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RestaurantViewSet, CreateUserView, RestaurantMenuView, 
    CartItemViewSet, OrderListCreateView, OrderDetailView, 
    AvailableOrderListView, RiderOrderViewSet, MenuItemListByRestaurantView,
    ModifierGroupViewSet, ModifierViewSet, MenuItemCreateView,
    DashboardAnalyticsView # Will be created next
)
from rest_framework.authtoken.views import obtain_auth_token

router = DefaultRouter()
router.register(r'restaurants', RestaurantViewSet, basename='restaurant')
router.register(r'cart-items', CartItemViewSet, basename='cart-item')
router.register(r'rider/orders', RiderOrderViewSet, basename='rider-order')
router.register(r'modifier-groups', ModifierGroupViewSet, basename='modifier-group')
router.register(r'modifiers', ModifierViewSet, basename='modifier')

urlpatterns = [
    path('', include(router.urls)),
    # Order URLs
    path('orders/', OrderListCreateView.as_view(), name='order-list-create'),
    path('orders/<int:pk>/', OrderDetailView.as_view(), name='order-detail'),

    # Restaurant URLs
    path('restaurants/<int:restaurant_pk>/menu/', RestaurantMenuView.as_view(), name='restaurant-menu'),
    path('restaurants/<int:restaurant_pk>/menu-items/', MenuItemListByRestaurantView.as_view(), name='restaurant-menu-items'),
    path('menu-items/create/', MenuItemCreateView.as_view(), name='menu-item-create'),

    # Auth URLs
    path('register/', CreateUserView.as_view(), name='register'),
    path('login/', obtain_auth_token, name='login'),

    # Rider URLs
    path('rider/available-orders/', AvailableOrderListView.as_view(), name='available-orders-list'),

    # Dashboard URLs
    path('dashboard-analytics/', DashboardAnalyticsView.as_view(), name='dashboard-analytics'),
]
