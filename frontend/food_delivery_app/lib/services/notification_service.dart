import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:food_delivery_app/services/api_service.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must initialize Firebase in the background isolate.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  if (message.notification != null) {
    // Use a local notification to show the message to the user
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'order_status_updates_background', // Unique ID for background channel
      'Order Status Updates (Background)',
      channelDescription: 'Notifications about food order status when the app is in the background.',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        message.notification!.body!,
        htmlFormatBigText: true,
        contentTitle: message.notification!.title!,
        htmlFormatContentTitle: true,
      ),
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      platformChannelSpecifics,
    );
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.navigatorKey});

  Future<void> initialize() async {
    // Set the background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission for iOS
    await _firebaseMessaging.requestPermission();

    // Initialize local notifications for foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, 
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap when app is in the foreground
        if (response.payload != null) {
          // Assuming payload is the orderId
          navigatorKey.currentState?.pushNamed(
            '/order-details',
            arguments: {'orderId': int.parse(response.payload!)},
          );
        }
      }
    );

    // Get FCM token
    final String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      String deviceType = Platform.isAndroid ? 'android' : 'ios';
      await ApiService().registerDevice(token, deviceType);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handler for when a notification is tapped from background/terminated state
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

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    _firebaseMessaging.getInitialMessage().then(_handleMessage);
  }

  void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'order_status_updates', // id
      'Order Status Updates', // name
      channelDescription: 'Notifications about the status of your food orders.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      styleInformation: BigTextStyleInformation(
        notification.body!,
        htmlFormatBigText: true,
        contentTitle: notification.title!,
        htmlFormatContentTitle: true,
      ),
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: message.data['orderId'], // Pass orderId as payload
    );
  }
}
