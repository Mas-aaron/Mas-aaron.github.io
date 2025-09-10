import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  final Function(Map<String, dynamic>) onMessageReceived;
  bool _isConnected = false;

  WebSocketService({required this.onMessageReceived});

  void connect(String token) {
    if (kDebugMode) {
      print('[WebSocket] WebSocket connections are temporarily disabled.');
      print('[WebSocket] Backend is running in WSGI mode without WebSocket support.');
    }
    // WebSocket connections disabled - backend running without Channels/Redis
    return;
  }

  void disconnect() {
    if (_channel != null) {
      _streamSubscription?.cancel();
      _channel!.sink.close();
      _isConnected = false;
      if (kDebugMode) {
        print('[WebSocket] Disconnecting.');
      }
    }
  }
}
