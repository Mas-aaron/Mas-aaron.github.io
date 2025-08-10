import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  bool get isLoggedIn => _token != null;
  String? get token => _token;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _token = await AuthService.getToken();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final token = await _authService.login(username, password);
    if (token != null) {
      _token = token;
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final deviceType = Platform.isAndroid ? 'android' : 'ios';
          await _apiService.registerDevice(fcmToken, deviceType);
        }
      } catch (e) {
        print('Failed to register device after login: $e');
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _apiService.unregisterDevice(fcmToken);
      }
    } catch (e) {
      print('Failed to unregister device during logout: $e');
    }
    await _authService.logout();
    _token = null;
    notifyListeners();
  }
}
