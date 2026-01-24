import 'dart:convert';
import 'package:food_delivery_app/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final String _baseUrl = baseUrl;

  Future<String?> login(String username, String password) async {
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
      final token = jsonDecode(response.body)['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // Notification service is initialized in main.dart
      return token;
    } else {
      print('Failed to login: ${response.body}');
      return null;
    }

  }

  Future<String?> loginWithGoogleIdToken(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/google/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'id_token': idToken,
      }),
    );

    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      return token;
    } else {
      print('Failed to login with Google: ${response.body}');
      return null;
    }
  }

  Future<bool> register(String username, String email, String password, String passwordConfirm) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
            body: jsonEncode(<String, String>{
        'username': username,
        'email': email,
        'password': password,
        'password2': passwordConfirm,
      }),
    );

            if (response.statusCode == 201) {
      return true;
    } else {
      // Optionally, log the error for debugging
      print('Failed to register: ${response.body}');
      return false;
    }
  }

  Future<void> logout() async {
    final ApiService apiService = ApiService();
    try {
      // Get the current FCM token
      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      // Unregister the device from the backend
      await apiService.unregisterDevice(fcmToken);
    } catch (e) {
      print('Could not unregister device during logout: $e');
      // We don't want to block logout if this fails
    }

    // Finally, clear the local token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}

