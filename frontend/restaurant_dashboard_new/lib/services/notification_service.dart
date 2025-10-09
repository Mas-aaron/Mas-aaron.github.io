import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:restaurant_dashboard_new/models/notification.dart' as AppNotification;
import '../constants.dart';

class NotificationService {
  final String _apiBaseUrl = baseUrl;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final GlobalKey<NavigatorState>? navigatorKey;

  NotificationService({this.navigatorKey});

  // Initialize Firebase messaging for restaurants
  Future<void> initialize() async {
    print('🔔 Initializing restaurant notification service...');
    
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Restaurant notification permission granted');
      
      // Get the token for this device
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 Restaurant FCM Token: ${token.substring(0, 20)}...');
        await _registerDeviceToken(token);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
      
      // Handle app opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessageTap(initialMessage);
      }
    } else {
      print('❌ Restaurant notification permission denied');
    }
  }

  // Register device token with backend for restaurant
  Future<void> _registerDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');
      
      if (authToken == null) {
        print('⚠️ No auth token found, skipping device registration');
        return;
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/register-restaurant-device/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'fcm_token': token,
          'device_type': 'restaurant',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Restaurant device token registered successfully');
      } else {
        print('❌ Failed to register restaurant device token: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error registering restaurant device token: $e');
    }
  }

  // Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('🔔 New order notification received: ${message.notification?.title}');
    
    if (navigatorKey?.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.restaurant_menu, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.notification?.title ?? 'New Order',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (message.notification?.body != null)
                      Text(message.notification!.body!),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _navigateToOrders(),
          ),
        ),
      );
    }
  }

  // Handle background message taps (when notification is tapped)
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('🔔 Restaurant notification tapped: ${message.data}');
    _navigateToOrders();
  }

  // Navigate to orders screen
  void _navigateToOrders() {
    if (navigatorKey?.currentContext != null) {
      // Navigate to order management screen (index 1 in the main navigation)
      // This assumes the home screen has a method to change tabs
      print('📱 Navigating to orders screen...');
    }
  }

  Future<List<AppNotification.Notification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/notifications/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => AppNotification.Notification.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }
}
