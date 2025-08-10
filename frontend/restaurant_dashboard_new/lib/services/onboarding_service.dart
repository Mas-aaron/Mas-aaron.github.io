import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  // Assumption: The base URL is stored in a central config file.
  // Using the local development server URL as a placeholder.
    final String _baseUrl = 'http://127.0.0.1:8000/api';

  // Assumption: The auth token is stored in SharedPreferences after login.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

    Future<http.Response> signUpRestaurant({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String username,
    required String password,
    required String password2,
  }) async {
    final response = await http.post(
            Uri.parse('$_baseUrl/register/restaurant/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
            body: jsonEncode({
        'name': name,
        'address': address,
        'phone_number': phone,
        'email': email, // Restaurant's contact email
        'owner': {
          'username': username,
          'email': email,
          'password': password,
          'password2': password2
        }
      }),
    );

    if (response.statusCode == 201) {
      // Handle successful signup
      return response;
    } else {
      // Handle error
      throw Exception('Failed to sign up restaurant: ${response.body}');
    }
  }



  Future<String> getOrderProtocol() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/order-protocol/'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['protocol'];
    } else {
      throw Exception('Failed to get order protocol: ${response.body}');
    }
  }

  Future<http.Response> updateOrderProtocol(String protocol) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/order-protocol/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(<String, String>{
        'protocol': protocol,
      }),
    );

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Failed to update order protocol: ${response.body}');
    }
  }




}
