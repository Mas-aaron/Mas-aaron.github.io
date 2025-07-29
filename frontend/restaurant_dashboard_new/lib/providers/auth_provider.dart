import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  String? _token;
  bool _isAuthenticated = false;

  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final token = await _authService.login(username, password);
    _token = token;
    _isAuthenticated = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    notifyListeners();
  }
}
