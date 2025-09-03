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
    if (_isConnected) {
      if (kDebugMode) {
        print('[WebSocket] Already connected.');
      }
      return;
    }
    // URL for the restaurant dashboard WebSocket
    final url = '$webSocketUrl/ws/restaurant/orders/?token=$token';
    try {
      if (kDebugMode) {
        print('[WebSocket] Connecting to $url');
      }
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      _streamSubscription = _channel!.stream.listen(
        (data) {
          try {
            final message = json.decode(data);
            onMessageReceived(message);
          } catch (e) {
            if (kDebugMode) {
              print('[WebSocket] Error parsing message: $e');
            }
          }
        },
        onDone: () {
          _isConnected = false;
          if (kDebugMode) {
            print('[WebSocket] Disconnected.');
          }
          // Optional: Implement reconnection logic here
        },
        onError: (error) {
          _isConnected = false;
          if (kDebugMode) {
            print('[WebSocket] Connection error: $error');
            print('[WebSocket] Make sure the backend server is running on $webSocketUrl');
          }
          // Attempt reconnection after 5 seconds
          Timer(const Duration(seconds: 5), () {
            if (!_isConnected) {
              if (kDebugMode) {
                print('[WebSocket] Attempting to reconnect...');
              }
              // Store token for reconnection
              final currentToken = token;
              connect(currentToken);
            }
          });
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[WebSocket] Connection error: $e');
      }
      _isConnected = false;
    }
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
