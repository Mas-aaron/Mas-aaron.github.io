import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:rider_app/services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Must be a top-level function (not a class method)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
  showNotification(message);
}

void showNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification != null) {
    flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription: 'This channel is used for important notifications.', // description
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher', // Ensure you have this icon
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['orderId']);
  }
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(initializationSettings);

    // Handle incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }
      showNotification(message);
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
