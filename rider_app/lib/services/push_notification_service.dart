import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:rider_app/services/api_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission for notifications.');
      }

      // Get the initial FCM token
      String? token = await _fcm.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('Firebase Messaging Token: $token');
        }
        await _registerDeviceToken(token);
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen(_registerDeviceToken);

    } else {
      if (kDebugMode) {
        print('User declined or has not accepted notification permissions.');
      }
    }

    // Handle incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
       }

      if (message.notification != null) {
         if (kDebugMode) {
          print('Message also contained a notification: ${message.notification}');
         }
      }
    });
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      final String deviceType = Platform.isAndroid ? 'android' : 'ios';
      await _apiService.registerDevice(token, deviceType);
      if (kDebugMode) {
        print('Device token registered successfully with backend.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register device token with backend: $e');
      }
    }
  }
}
