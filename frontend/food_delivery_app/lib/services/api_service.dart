import 'dart:convert';

import 'package:food_delivery_app/models/cart_item.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';

class ApiService {
  final String _baseUrl = baseUrl;
  Future<void> register(String username, String email, String password, String password2) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'password2': password2,
      }),
    );

    if (response.statusCode == 201) {
      return; // Success
    } else {
      String errorMessage = 'Failed to register.';
      if (response.body.isNotEmpty) {
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Combine all error messages for better feedback
            errorMessage = errorData.entries
                .map((entry) =>
                    '${entry.key.toUpperCase()}: ${entry.value.join(', ')}')
                .join('\n');
          }
        } catch (e) {
          // Fallback if the body is not valid JSON or has an unexpected format
          errorMessage = response.body;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }



  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Token not found. Please log in again.');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Token $token',
    };
  }

  Future<List<Restaurant>> fetchRestaurants({double? lat, double? lng}) async {
    String url = '$_baseUrl/restaurants/';
    if (lat != null && lng != null) {
      url += '?lat=$lat&lng=$lng';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Restaurant> restaurants = body.map((dynamic item) => Restaurant.fromJson(item)).toList();
      return restaurants;
    } else {
      throw Exception('Failed to load restaurants');
    }
  }

  Future<List<Order>> fetchOrders() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/orders/'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Order> orders = body.map((dynamic item) => Order.fromJson(item)).toList();
      return orders;
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<List<MenuCategory>> fetchMenu(int restaurantId) async {
    final response = await http.get(Uri.parse('$_baseUrl/restaurants/$restaurantId/menu/'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<MenuCategory> menu = body.map((dynamic item) => MenuCategory.fromJson(item)).toList();
      return menu;
    } else {
      throw Exception('Failed to load menu');
    }
  }

  Future<List<MenuItem>> fetchMenuItems(int restaurantId) async {
    final response = await http.get(Uri.parse('$_baseUrl/restaurants/$restaurantId/menu-items/'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<MenuItem> items = body.map((dynamic item) => MenuItem.fromJson(item)).toList();
      return items;
    } else {
      throw Exception('Failed to load menu items');
    }
  }

  Future<List<CartItem>> getCartItems() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/cart-items/'), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<CartItem> items = body.map((dynamic item) => CartItem.fromJson(item)).toList();
      return items;
    } else {
      throw Exception('Failed to load cart items');
    }
  }

  Future<CartItem> addToCart(int menuItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'menu_item_id': menuItemId,
      'quantity': quantity,
    });
    final response = await http.post(Uri.parse('$_baseUrl/cart-items/'), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add item to cart');
    }
  }

  Future<CartItem> updateCartItem(int cartItemId, int quantity) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'quantity': quantity});
    final response = await http.patch(Uri.parse('$_baseUrl/cart-items/$cartItemId/'), headers: headers, body: body);

    if (response.statusCode == 200) {
      return CartItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update cart item');
    }
  }

  Future<void> deleteCartItem(int cartItemId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/cart-items/$cartItemId/'), headers: headers);

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
    final response = await http.post(Uri.parse('$_baseUrl/orders/'), headers: headers, body: body);

    if (response.statusCode == 201) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      // Log the full error response to the console for debugging
      print('Failed to place order. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      String errorMessage = 'Failed to place order. Please check the details and try again.';
      if (response.body.isNotEmpty) {
        try {
          // Attempt to parse a more specific error message from the JSON response
          var errorJson = jsonDecode(response.body);
          // DRF often returns errors as a map of field names to a list of errors
          errorMessage = errorJson.entries.map((entry) => '${entry.key}: ${entry.value.join(', ')}').join('\n');
        } catch (e) {
          // If parsing fails, use the raw body as the error message
          errorMessage = response.body;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<Order>> getOrders() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/orders/'), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Order> orders = body.map((dynamic item) => Order.fromJson(item)).toList();
      return orders;
    } else {
      throw Exception('Failed to fetch orders');
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/orders/$orderId/'), headers: headers);

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch order details');
    }
  }
}
