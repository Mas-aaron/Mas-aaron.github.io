import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:rider_app/models/order.dart';
import 'package:rider_app/constants.dart';

class ApiService {
    final String _baseUrl = '$backendUrl/api';
  String? _token;

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      _token = jsonDecode(response.body)['token'];
      // Save token
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(response.body);
      await prefs.setString('authToken', data['token']);
      return true; // Login successful
    } else {
      return false;
    }
  }

  Future<List<Order>> getAvailableOrders() async {
    if (_token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/rider/available-orders/'),
      headers: <String, String>{
        'Authorization': 'Token $_token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Order.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load available orders');
    }
  }

  Future<Order> acceptOrder(int orderId) async {
    if (_token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/rider/available-orders/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode({'order_id': orderId}),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to accept order.');
    }
  }

  Future<List<Order>> getAssignedOrders() async {
    if (_token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/rider/orders/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $_token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Order> orders = body.map((dynamic item) => Order.fromJson(item)).toList();
      return orders;
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }
}
