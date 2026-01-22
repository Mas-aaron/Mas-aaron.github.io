from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken.views import obtain_auth_token

from . import views as api_views
from . import views_mtn_setup


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
from .rider_arrival_views import RiderArrivalView, RiderLocationUpdateView
router.register(r'reviews', api_views.ReviewViewSet, basename='review')
router.register(r'order-reviews', api_views.OrderReviewViewSet, basename='order-review')
router.register(r'rider-reviews', api_views.RiderReviewViewSet, basename='rider-review')
router.register(r'bills', api_views.BillViewSet, basename='bill')
router.register(r'payment-periods', api_views.PaymentPeriodViewSet, basename='payment-period')
router.register(r'order-payments', api_views.OrderPaymentViewSet, basename='order-payment')
router.register(r'bank-accounts', api_views.BankAccountViewSet, basename='bank-account')
router.register(r'payment-disputes', api_views.PaymentDisputeViewSet, basename='payment-dispute')
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

    # Payments - MTN callback (sandbox)
    path('payments/mtn/callback/', api_views.mtn_payment_callback, name='mtn-payment-callback'),
    # Payments - Airtel Money callback
    path('payments/airtel/callback/', api_views.airtel_payment_callback, name='airtel-payment-callback'),
    path('orders/<int:order_id>/notify-arrival/', api_views.NotifyArrivalView.as_view(), name='order-notify-arrival'),

    # Restaurant URLs
    path('restaurants/<int:restaurant_pk>/menu-items/', api_views.MenuItemListByRestaurantView.as_view(), name='restaurant-menu-items'),

    # Auth URLs
    path('register/', api_views.CreateUserView.as_view(), name='register'),
    path('register/restaurant/', api_views.RestaurantSignUpView.as_view(), name='restaurant-signup'),
    path('login/', obtain_auth_token, name='login'),
    path('me/', api_views.CurrentUserView.as_view(), name='current-user'),
    path('promo-codes/', api_views.PromoCodeListView.as_view(), name='promo-code-list'),
    path('promo-codes/apply/', api_views.ApplyPromoCodeView.as_view(), name='promo-code-apply'),
    path('restaurant/promo-codes/', api_views.RestaurantPromoCodeListCreateView.as_view(), name='restaurant-promo-code-list-create'),
    path('restaurant/promo-codes/<int:promo_id>/', api_views.RestaurantPromoCodeDetailView.as_view(), name='restaurant-promo-code-detail'),
    path('admin/promo-codes/', api_views.AdminPromoCodeListCreateView.as_view(), name='admin-promo-code-list-create'),
    path('admin/promo-codes/<int:promo_id>/', api_views.AdminPromoCodeDetailView.as_view(), name='admin-promo-code-detail'),
    path('admin/promo-codes/<int:promo_id>/redemptions/', api_views.AdminPromoCodeRedemptionsView.as_view(), name='admin-promo-code-redemptions'),
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

    # Notification URLs
    path('register-restaurant-device/', api_views.register_restaurant_device, name='register-restaurant-device'),
    path('register-rider-device/', api_views.register_rider_device, name='register-rider-device'),
    
    # Password Recovery URLs
    path('password-reset-request/', api_views.password_reset_request, name='password-reset-request'),
    path('password-reset-confirm/', api_views.password_reset_confirm, name='password-reset-confirm'),
    path('password-otp-request/', api_views.password_otp_request, name='password-otp-request'),
    path('password-otp-confirm/', api_views.password_otp_confirm, name='password-otp-confirm'),
    path('change-password/', api_views.change_password, name='change_password'),
    
    # Payment endpoints
    path('payments/initiate/', api_views.initiate_payment, name='initiate_payment'),
    path('payments/<int:payment_id>/status/', api_views.check_payment_status, name='check_payment_status'),
    path('payments/status/<int:payment_id>/', api_views.check_payment_status, name='check_payment_status_alt'),
    path('payments/<int:payment_id>/cancel/', api_views.cancel_payment, name='cancel_payment'),
    path('payments/<int:payment_id>/complete/', api_views.complete_payment, name='complete_payment'),
    path('payments/history/', api_views.payment_history, name='payment_history'),
    path('payments/pesapal-callback/', api_views.pesapal_callback, name='pesapal_callback'),
    path('payments/pesapal-ipn/', api_views.pesapal_ipn, name='pesapal_ipn'),
    
    # MTN Setup URLs (One-time use for Render free tier)
    path('mtn-setup/create-user/', views_mtn_setup.mtn_setup_create_user, name='mtn-setup-create-user'),
    path('mtn-setup/get-api-key/', views_mtn_setup.mtn_setup_get_api_key, name='mtn-setup-get-api-key'),
    path('mtn-setup/test-credentials/', views_mtn_setup.mtn_setup_test_credentials, name='mtn-setup-test-credentials'),
    
    # Test/Debug URLs
    path('health/', api_views.health_check, name='health-check'),
    path('test-notification/', api_views.test_notification, name='test-notification'),
    path('test-restaurant-notification/', api_views.test_restaurant_notification, name='test-restaurant-notification'),
    path('send-template-notification/', api_views.SendTemplateNotificationView.as_view(), name='send-template-notification'),
    path('configure-gcs/', api_views.configure_gcs_bucket, name='configure-gcs'),
    path('test-gcs/', api_views.test_gcs_connection, name='test-gcs-connection'),
    path('debug-pesapal/', api_views.debug_pesapal_config, name='debug-pesapal'),
    path('debug-mtn/', api_views.debug_mtn_config, name='debug-mtn'),
    path('test-mtn-payment/', api_views.test_mtn_payment, name='test-mtn-payment'),
]

# Combine all URL patterns
urlpatterns = custom_urlpatterns + router.urls + custom_router.urls
