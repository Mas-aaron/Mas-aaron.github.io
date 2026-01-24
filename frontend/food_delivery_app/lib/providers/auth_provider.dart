import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  bool get isLoggedIn => _token != null;
  String? get token => _token;

  AuthProvider() {
    _initAuth();
  }

  Future<bool> loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return false;
      }

      final token = await _authService.loginWithGoogleIdToken(idToken);
      if (token == null) {
        return false;
      }

      _token = token;
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final deviceType = Platform.isAndroid ? 'android' : 'ios';
          await _apiService.registerDevice(fcmToken, deviceType);
        }
      } catch (e) {
        print('Failed to register device after Google login: $e');
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('Google login failed: $e');
      return false;
    }
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
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
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
