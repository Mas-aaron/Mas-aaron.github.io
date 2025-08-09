import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_delivery_app/services/api_service.dart';

// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('--- BACKGROUND MESSAGE HANDLER ---');
  print('Message ID: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Notification: ${message.notification?.title} / ${message.notification?.body}');
  print('---------------------------------');
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

    Future<void> initialize() async {
    print('[PushNotificationService] Initializing...');
    // Set the background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    NotificationSettings settings = await _fcm.requestPermission();

        print('[PushNotificationService] Notification permission status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[PushNotificationService] User granted permission.');
      _setupForegroundMessageHandler();
      await _registerDeviceToken();
    } else {
      print('[PushNotificationService] User declined or has not accepted permission.');
    }
  }

  void _setupForegroundMessageHandler() {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('--- FOREGROUND MESSAGE RECEIVED ---');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Notification: ${message.notification?.title} / ${message.notification?.body}');
      }
      print('-----------------------------------');
      _showLocalNotification(message);
    });
  }

    Future<void> _registerDeviceToken() async {
    try {
      print('[PushNotificationService] Registering device token...');
      String? token = await _fcm.getToken();
      if (token != null) {
        print('[PushNotificationService] FCM Token obtained: $token');
        await _sendTokenToBackend(token);
      } else {
        print('[PushNotificationService] Failed to get FCM token.');
      }
      _fcm.onTokenRefresh.listen((newToken) {
        print('[PushNotificationService] FCM Token refreshed: $newToken');
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      print('[PushNotificationService] Error getting FCM token: $e');
    }
  }

    Future<void> _sendTokenToBackend(String token) async {
    try {
      print('[PushNotificationService] Sending token to backend...');
      String deviceType = Platform.isIOS ? 'ios' : 'android';
      await _apiService.registerDevice(token, deviceType);
      print('[PushNotificationService] Token sent to backend successfully.');
    } catch (e) {
      print('[PushNotificationService] ERROR sending token to backend: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    if (notification == null) return;

    final String? imageUrl = notification.android?.imageUrl ?? notification.apple?.imageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String imagePath = await _downloadAndSaveFile(imageUrl, 'notification_image.jpg');
        final BigPictureStyleInformation bigPictureStyleInformation =
            BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          largeIcon: FilePathAndroidBitmap(imagePath),
          contentTitle: notification.title,
          htmlFormatContentTitle: true,
          summaryText: notification.body,
          htmlFormatSummaryText: true,
        );

        final AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'high_importance_channel_big_picture',
          'High Importance Notifications with Images',
          channelDescription: 'Channel for notifications with images.',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigPictureStyleInformation,
          icon: '@mipmap/ic_launcher',
        );

        final NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformChannelSpecifics,
        );
      } catch (e) {
        print('Error with image notification: $e');
        _showSimpleNotification(notification);
      }
    } else {
      _showSimpleNotification(notification);
    }
  }

  void _showSimpleNotification(RemoteNotification notification) {
    _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getTemporaryDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }
}
