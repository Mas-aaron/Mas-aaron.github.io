import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  NotificationService? _notificationService;

  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      if (_token != null) {
        _isAuthenticated = true;
        // Initialize notifications for existing authenticated user
        await _initializeNotifications();
      }
    } catch (e) {
      print('Error loading token: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final token = await _authService.login(username, password);
    _token = token;
    _isAuthenticated = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);

    // Initialize notifications after successful login
    await _initializeNotifications();

    notifyListeners();
  }

  Future<void> _initializeNotifications() async {
    try {
      print('🔔 Initializing restaurant notifications...');
      _notificationService = NotificationService();
      await _notificationService!.initialize();
      print('✅ Restaurant notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing restaurant notifications: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    notifyListeners();
  }
}
