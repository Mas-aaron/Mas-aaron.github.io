import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:restaurant_dashboard_new/models/order.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/constants.dart';

class OrderService {
  Future<List<Order>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/restaurant-orders/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
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

  Future<void> updateOrderStatus(int orderId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/orders/$orderId/update-status/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(<String, String>{
        'status': status,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update order status. Status code: ${response.statusCode}');
    }
  }
}
