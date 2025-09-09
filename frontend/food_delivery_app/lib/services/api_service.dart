import 'dart:convert';
import 'dart:io';

import 'package:food_delivery_app/models/cart.dart';
import 'package:food_delivery_app/models/cart_item.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:food_delivery_app/services/auth_service.dart';
import 'package:food_delivery_app/widgets/order_type_selector.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/restaurant.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/review.dart';


class ApiService {
  final String _baseUrl = baseUrl;
  
  // HTTP client with extended timeout and SSL bypass for Railway connection
  static final http.Client _client = _createHttpClient();
  
  static http.Client _createHttpClient() {
    final httpClient = HttpClient();
    // Bypass SSL certificate validation for development
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }
  
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }
  
  // Helper method for HTTP requests with timeout
  Future<http.Response> _makeRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse(url);
    
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          return await _client.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          return await _client.post(uri, headers: headers, body: body).timeout(timeout);
        case 'PUT':
          return await _client.put(uri, headers: headers, body: body).timeout(timeout);
        case 'DELETE':
          return await _client.delete(uri, headers: headers).timeout(timeout);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      print('HTTP Request Error: $e');
      rethrow;
    }
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
      'registration_id': fcmToken,
      'type': deviceType,
    });

    print('--- Registering Device ---');
    print('URL: $_baseUrl/devices/');
    print('Headers: $headers');
    print('Body: $requestBody');

    try {
      final response = await _makeRequest(
        'POST',
        '$_baseUrl/devices/',
        headers: headers,
        body: requestBody,
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        print('Failed to register device: ${response.body}');
        throw Exception('Failed to register device');
      }
    } catch (e) {
      print('Error registering device: $e');
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
      'registration_id': fcmToken,
    });

    print('--- Unregistering Device ---');
    print('URL: $_baseUrl/devices/unregister/');
    print('Headers: $headers');
    print('Body: $requestBody');

    try {
      final response = await _makeRequest(
        'POST',
        '$_baseUrl/devices/unregister/',
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
    String url = '$_baseUrl/restaurants/';
    if (lat != null && lng != null) {
      url += '?lat=$lat&lng=$lng';
    }
    final response = await _makeRequest('GET', url);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Restaurant.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load restaurants');
    }
  }

  Future<List<Order>> fetchOrders() async {
    final headers = await _getAuthHeaders();
    print('--- Fetching Orders ---');
    print('URL: $_baseUrl/orders/');
    print('Headers: $headers');
    
    final response = await _makeRequest('GET', '$_baseUrl/orders/', headers: headers);
    
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Order> orders = [];
      
      for (int i = 0; i < body.length; i++) {
        try {
          orders.add(Order.fromJson(body[i]));
        } catch (e) {
          print('Error parsing order at index $i: $e');
          print('Order data: ${body[i]}');
          // Skip this order and continue with the rest
        }
      }
      
      return orders;
    } else {
      print('Error fetching orders: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<List<MenuCategory>> fetchMenu(int restaurantId) async {
    final response = await _makeRequest('GET', '$_baseUrl/restaurants/$restaurantId/menu/');
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MenuCategory.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load menu');
    }
  }

  Future<List<MenuItem>> fetchMenuItems(int restaurantId, {List<int>? dietaryPreferenceIds}) async {
    var uri = Uri.parse('$_baseUrl/restaurants/$restaurantId/menu-items/');
    if (dietaryPreferenceIds != null && dietaryPreferenceIds.isNotEmpty) {
      final queryParameters = {
        'dietary_preferences': dietaryPreferenceIds.map((id) => id.toString()).toList(),
      };
      uri = uri.replace(queryParameters: queryParameters);
    }
    final response = await _makeRequest('GET', uri.toString());
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MenuItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load menu items');
    }
  }

  Future<List<CartItem>> getCartItems() async {
    final headers = await _getAuthHeaders();
    final response = await _makeRequest('GET', '$_baseUrl/cart-items/', headers: headers);
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
    final response = await _makeRequest('POST', '$_baseUrl/cart/add/', headers: headers, body: body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add item to cart');
    }
  }

  Future<CartItem> updateCartItem(int cartItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'quantity': quantity});
    final response = await _makeRequest('PUT', '$_baseUrl/cart-items/$cartItemId/', headers: headers, body: body);
    if (response.statusCode == 200) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update cart item: ${response.body}');
    }
  }

  Future<void> deleteCartItem(int cartItemId) async {
    final headers = await _getAuthHeaders();
    final response = await _makeRequest('DELETE', '$_baseUrl/cart-items/$cartItemId/', headers: headers);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete cart item');
    }
  }

  Future<Order> placeOrder(
    String deliveryAddress, 
    double latitude, 
    double longitude, {
    OrderType? orderType,
    DateTime? scheduledTime,
    double? tipAmount,
    String? tableNumber,
  }) async {
    final headers = await _getAuthHeaders();
    
    final orderData = <String, dynamic>{
      'delivery_address': deliveryAddress,
    };
    
    // Only add location data for delivery orders
    if (orderType == OrderType.delivery) {
      orderData['customer_lat'] = latitude;
      orderData['customer_lng'] = longitude;
    }
    
    // Add dine-in specific fields
    if (orderType != null) {
      String orderTypeString = orderType.toString().split('.').last;
      // Convert camelCase to snake_case for backend compatibility
      if (orderTypeString == 'dineIn') {
        orderTypeString = 'dine_in';
      }
      orderData['order_type'] = orderTypeString;
    }
    
    if (scheduledTime != null) {
      orderData['scheduled_time'] = scheduledTime.toIso8601String();
    }
    
    if (tipAmount != null && tipAmount > 0) {
      orderData['tip_amount'] = tipAmount;
    }
    
    if (tableNumber != null && tableNumber.isNotEmpty) {
      orderData['table_number'] = tableNumber;
    }
    
    final body = jsonEncode(orderData);
    final response = await _makeRequest('POST', '$_baseUrl/orders/', headers: headers, body: body);
    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      print('Failed to place order. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // Parse error message from response
      String errorMessage = 'Failed to place order.';
      try {
        final responseBody = jsonDecode(response.body);
        if (responseBody is List && responseBody.isNotEmpty) {
          errorMessage = responseBody.first.toString();
        } else if (responseBody is Map && responseBody.containsKey('error')) {
          errorMessage = responseBody['error'].toString();
        }
      } catch (e) {
        // Keep default message if parsing fails
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    final headers = await _getAuthHeaders();
    final response = await _makeRequest('GET', '$_baseUrl/orders/$orderId/', headers: headers);
    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch order details');
    }
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final apiKey = googleMapsApiKey;
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';
    final response = await _makeRequest('GET', url);
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

  Future<void> submitReview({
    required int menuItemId,
    required double rating,
    required String comment,
  }) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'menu_item': menuItemId,
      'rating': rating,
      'comment': comment,
    });
    final response = await _makeRequest('POST', '$_baseUrl/reviews/', headers: headers, body: body);
    if (response.statusCode != 201) {
      throw Exception('Failed to submit review');
    }
  }

  Future<void> submitOrderReview({
    required int orderId,
    required double rating,
    required String comment,
  }) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'order': orderId,
      'rating': rating,
      'comment': comment,
    });
    final response = await _makeRequest('POST', '$_baseUrl/order-reviews/', headers: headers, body: body);
    if (response.statusCode != 201) {
      throw Exception('Failed to submit order review: ${response.body}');
    }
  }

  Future<void> submitRiderReview({
    required int orderId,
    required int riderId,
    required double rating,
    required String comment,
  }) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'order': orderId,
      'rider': riderId,
      'rating': rating,
      'comment': comment,
    });
    final response = await _makeRequest('POST', '$_baseUrl/rider-reviews/', headers: headers, body: body);
    if (response.statusCode != 201) {
      throw Exception('Failed to submit rider review: ${response.body}');
    }
  }

  Future<List<Review>> getReviews(int menuItemId) async {
    final response = await _makeRequest('GET', '$_baseUrl/reviews/?menu_item_id=$menuItemId');
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
    print('URL: $_baseUrl/test-notification/');
    print('Headers: $headers');

    try {
      final response = await _makeRequest('POST', '$_baseUrl/test-notification/', headers: headers);

      if (response.statusCode == 200) {
        print('Test notification API call successful: ${response.body}');
      } else {
        print('Failed to send test notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  Future<void> logout() async {
    // Implement logout logic
  }

  Future<Cart> getCart() async {
    final headers = await _getAuthHeaders();
    final response = await _makeRequest('GET', '$_baseUrl/cart/', headers: headers);

    if (response.statusCode == 200) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load cart: ${response.body}');
    }
  }

  Future<void> removeCartItem(int cartItemId) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'cart_item_id': cartItemId});
    final response = await _makeRequest('POST', '$_baseUrl/cart/remove/', headers: headers, body: body);

    if (response.statusCode != 204) {
      throw Exception('Failed to remove item from cart: ${response.body}');
    }
  }

  Future<void> updateCartItemQuantity(int cartItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'quantity': quantity});
    final response = await _makeRequest('PUT', '$_baseUrl/cart/update/$cartItemId/', headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Failed to update item quantity: ${response.body}');
    }
  }
}
