import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/models/message.dart'; // Contains the User model
import '../constants.dart';

class AuthService {
  final String _apiBaseUrl = baseUrl;

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/login/'), // Corrected login endpoint
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        return token;
      }
      throw Exception('Token not found in response');
    } else {
      // Attempt to parse a more specific error message
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData.toString());
      } catch (e) {
        throw Exception('Failed to login. Status code: ${response.statusCode}');
      }
    }
  }

  Future<Map<String, dynamic>> requestPasswordOtp(String email) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/password-otp-request/'),
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
      Uri.parse('$_apiBaseUrl/password-otp-confirm/'),
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
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/me/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete account');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<User> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/me/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  // Password Recovery Methods
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password-reset-request/'),
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
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/change-password/'),
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
}
