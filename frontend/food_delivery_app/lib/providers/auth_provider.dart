import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  final ApiService _apiService = ApiService();

  bool get isLoggedIn => _token != null;
  String? get token => _token;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    await _apiService.login(username, password);
    await _initAuth(); // Re-check token after login
  }

  Future<void> logout() async {
    await _apiService.logout();
    _token = null;
    notifyListeners();
  }
}
