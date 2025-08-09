import 'dart:convert';

import 'package:food_delivery_app/models/cart.dart';
import 'package:food_delivery_app/models/cart_item.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:food_delivery_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/review.dart';

class ApiService {
  final String _baseUrl = baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<void> registerDevice(String? fcmToken, String deviceType) async {
    if (fcmToken == null || fcmToken.isEmpty) {
      print("FCM token is null or empty, skipping device registration.");
      return;
    }

    final headers = await _getAuthHeaders();
    if (headers['Authorization'] == null) {
      print("No auth token found, skipping device registration.");
      return;
    }

    final requestBody = jsonEncode({
      'token': fcmToken,
      'device_type': deviceType,
    });

    print('--- Registering Device ---');
    print('URL: $_baseUrl/api/devices/');
    print('Headers: $headers');
    print('Body: $requestBody');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/devices/'),
      headers: headers,
      body: requestBody,
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      print('Failed to register device: ${response.body}');
      throw Exception('Failed to register device');
    }
  }

  Future<void> unregisterDevice(String? fcmToken) async {
    if (fcmToken == null || fcmToken.isEmpty) {
      print("FCM token is null or empty, skipping device unregistration.");
      return;
    }

    final headers = await _getAuthHeaders();
    if (headers['Authorization'] == null) {
      print("No auth token found, skipping device unregistration.");
      return;
    }

    final requestBody = jsonEncode({
      'token': fcmToken,
    });

    print('--- Unregistering Device ---');
    print('URL: $_baseUrl/api/devices/unregister/');
    print('Headers: $headers');
    print('Body: $requestBody');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/devices/unregister/'),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 204) {
        print('Device unregistered successfully');
      } else {
        print('Failed to unregister device: ${response.body}');
        // Not throwing an exception here to allow logout to complete even if unregister fails
      }
    } catch (e) {
      print('Error unregistering device: $e');
    }
  }

  Future<List<Restaurant>> fetchRestaurants({double? lat, double? lng}) async {
    String url = '$_baseUrl/api/restaurants/';
    if (lat != null && lng != null) {
      url += '?lat=$lat&lng=$lng';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Restaurant.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load restaurants');
    }
  }

  Future<List<Order>> fetchOrders() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/api/orders/'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Order.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<List<MenuCategory>> fetchMenu(int restaurantId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/restaurants/$restaurantId/menu/'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MenuCategory.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load menu');
    }
  }

  Future<List<MenuItem>> fetchMenuItems(int restaurantId, {List<int>? dietaryPreferenceIds}) async {
    var uri = Uri.parse('$_baseUrl/api/restaurants/$restaurantId/menu-items/');
    if (dietaryPreferenceIds != null && dietaryPreferenceIds.isNotEmpty) {
      final queryParameters = {
        'dietary_preferences': dietaryPreferenceIds.map((id) => id.toString()).toList(),
      };
      uri = uri.replace(queryParameters: queryParameters);
    }
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MenuItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load menu items');
    }
  }

  Future<List<CartItem>> getCartItems() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/api/cart-items/'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => CartItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load cart items');
    }
  }

  Future<CartItem> addToCart(int menuItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'menu_item_id': menuItemId, 'quantity': quantity});
    final response = await http.post(Uri.parse('$_baseUrl/api/cart-items/'), headers: headers, body: body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add item to cart');
    }
  }

  Future<CartItem> updateCartItem(int cartItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'quantity': quantity});
    final response = await http.patch(Uri.parse('$_baseUrl/api/cart-items/$cartItemId/'), headers: headers, body: body);
    if (response.statusCode == 200) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update cart item: ${response.body}');
    }
  }

  Future<void> deleteCartItem(int cartItemId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/api/cart-items/$cartItemId/'), headers: headers);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete cart item');
    }
  }

  Future<Order> placeOrder(String deliveryAddress, double latitude, double longitude) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'delivery_address': deliveryAddress,
      'customer_lat': latitude,
      'customer_lng': longitude,
    });
    final response = await http.post(Uri.parse('$_baseUrl/api/orders/'), headers: headers, body: body);
    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      print('Failed to place order. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to place order.');
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/api/orders/$orderId/'), headers: headers);
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch order details');
    }
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final apiKey = googleMapsApiKey;
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      } else {
        throw Exception('Failed to geocode coordinates: ${data['error_message'] ?? data['status']}');
      }
    } else {
      throw Exception('Failed to connect to Google Geocoding API');
    }
  }

  Future<void> submitReview(int menuItemId, double rating, String comment) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'menu_item': menuItemId,
      'rating': rating,
      'comment': comment,
    });
    final response = await http.post(
      Uri.parse('$_baseUrl/api/reviews/'),
      headers: headers,
      body: body,
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to submit review');
    }
  }

  Future<List<Review>> getReviews(int menuItemId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/reviews/?menu_item_id=$menuItemId'));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Review.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load reviews');
    }
  }

  Future<void> testPushNotification() async {
    final headers = await _getAuthHeaders();
    if (headers['Authorization'] == null) {
      print("No auth token found, skipping test notification.");
      return;
    }

    print('--- Sending Test Notification ---');
    print('URL: $_baseUrl/api/test-notification/');
    print('Headers: $headers');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/test-notification/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('Test notification API call successful: ${response.body}');
      } else {
        print('Failed to send test notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

    Future<Cart> getCart() async {
    final headers = await _getAuthHeaders();
    // Assuming the endpoint for the cart is /api/cart/. This is a standard REST convention.
    final response = await http.get(Uri.parse('$_baseUrl/api/cart/'), headers: headers);

    if (response.statusCode == 200) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load cart: ${response.body}');
    }
  }

  Future<void> removeCartItem(int cartItemId) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'cart_item_id': cartItemId});
    final response = await http.post(
      Uri.parse('$_baseUrl/api/cart/remove/'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to remove item from cart: ${response.body}');
    }
  }

  Future<void> updateCartItemQuantity(int cartItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'quantity': quantity});
    final response = await http.put(
      Uri.parse('$_baseUrl/api/cart/update/$cartItemId/'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update item quantity: ${response.body}');
    }
  }
}
