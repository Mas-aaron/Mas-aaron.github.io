import 'package:http/http.dart' as http;
import 'package:rider_app/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:rider_app/models/order.dart';
import 'package:rider_app/models/rider_review.dart';

class ApiService {
  final String _baseUrl = baseUrl;

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

    print('Login response: ${response.statusCode}');
    print('Login body: ${response.body}');
    
    if (response.statusCode == 200) {
      // Save token
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(response.body);
      await prefs.setString('authToken', data['token']);
      return true; // Login successful
    } else {
      print('Login failed: ${response.statusCode} - ${response.body}');
      return false; // Login failed
    }
  }

  Future<Map<String, dynamic>> requestPasswordOtp(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/password-otp-request/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
      }),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': responseData['message']};
    }
    return {
      'success': false,
      'message': responseData['error'] ?? 'Failed to send OTP',
    };
  }

  Future<Map<String, dynamic>> confirmPasswordOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/password-otp-confirm/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'message': responseData['message']};
    }
    return {
      'success': false,
      'message': responseData['error'] ?? 'Failed to reset password',
    };
  }

  Future<void> deleteCurrentUser() async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/me/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete account');
    }
  }

  Future<Map<String, dynamic>> signUp({required String email, required String password, required String firstName, required String lastName}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/rider/signup/'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );

    if (response.statusCode == 201) {
      return {'success': true};
    } else {
      String errorMessage = "An unknown error occurred. Please try again.";
      if (response.statusCode == 400) {
        try {
          final body = jsonDecode(response.body);
          if (body['email'] != null && body['email'] is List && body['email'].isNotEmpty) {
            errorMessage = body['email'][0];
          } else {
            errorMessage = "Invalid data provided. Please check your inputs.";
          }
        } catch (e) {
          // Keep the generic message if JSON parsing fails
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<List<Order>> getAvailableOrders() async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/rider/available-orders/'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    print('Available orders response: ${response.statusCode}');
    print('Available orders body: ${response.body}');
    
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Order.fromJson(item)).toList();
    } else {
      print('Failed to load available orders: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load available orders: ${response.statusCode}');
    }
  }

  Future<Order> acceptOrder(int orderId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/rider-orders/$orderId/accept/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to accept order.');
    }
  }

  Future<Order> getOrderDetails(int orderId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/rider-orders/$orderId/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load order details');
    }
  }

  Future<List<Order>> getAssignedOrders() async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/rider-orders/'),
      headers: <String, String>{
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

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  Future<Map<String, dynamic>> getDirections({
    required String origin,
    required String destination,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/directions/?origin=$origin&destination=$destination'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch directions: ${response.statusCode}');
    }
  }

  Future<void> completeOrder(int orderId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/rider-orders/$orderId/complete/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to complete order.');
    }
  }

  Future<void> registerDevice(String fcmToken, String deviceType) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/register-rider-device/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'fcm_token': fcmToken,
        'device_type': deviceType,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      print('Failed to register device: ${response.body}');
      throw Exception('Failed to register device.');
    }
  }

  Future<List<RiderReview>> fetchRiderReviews() async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/my-reviews/'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => RiderReview.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load rider reviews');
    }
  }

  Future<void> notifyArrival(int orderId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/orders/$orderId/notify-arrival/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to send arrival notification.');
      } catch (e) {
        throw Exception('Failed to send arrival notification.');
      }
    }
  }

  // Password Recovery Methods
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/password-reset-request/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
      }),
    );

    final responseData = jsonDecode(response.body);
    
    if (response.statusCode == 200) {
      return {'success': true, 'message': responseData['message']};
    } else {
      return {'success': false, 'message': responseData['error'] ?? 'Failed to send reset email'};
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final token = await ApiService.getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/change-password/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(<String, String>{
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    final responseData = jsonDecode(response.body);
    
    if (response.statusCode == 200) {
      return {'success': true, 'message': responseData['message']};
    } else {
      return {'success': false, 'message': responseData['error'] ?? 'Failed to change password'};
    }
  }

  // Logout method
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
  }
}
