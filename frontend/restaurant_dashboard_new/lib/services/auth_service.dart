import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // TODO: Move this to a constants file
  final String _baseUrl = 'https://mas-aarongithubio-production.up.railway.app/api';

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login/'), // Using the same login endpoint
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
}
