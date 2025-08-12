import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:food_delivery_app/services/api_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Get FCM token
        final String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      // Send token to your backend
      String deviceType = Platform.isAndroid ? 'android' : 'ios';
      await ApiService().registerDevice(token, deviceType);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message.notification!);
      }
    });

    // Handler for when a notification is tapped, both from background and terminated states.
    void _handleMessage(RemoteMessage? message) {
      if (message == null) return;

      final orderId = message.data['orderId'];
      if (orderId != null) {
        navigatorKey.currentState?.pushNamed(
          '/order-details',
          arguments: {'orderId': int.parse(orderId)},
        );
      }
    }

    // Handle notifications that are tapped when the app is in the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Handle notifications that are tapped when the app is terminated.
    _firebaseMessaging.getInitialMessage().then(_handleMessage);
  }

  void _showLocalNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'order_status_updates', // id
      'Order Status Updates', // name
      channelDescription: 'Notifications about the status of your food orders.', // description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }
}
