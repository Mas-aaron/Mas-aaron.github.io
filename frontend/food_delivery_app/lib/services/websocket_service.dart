import 'dart:async';
import 'dart:convert';
import 'package:food_delivery_app/services/auth_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:food_delivery_app/constants.dart';

class WebSocketService {
  final Function(Map<String, dynamic>) onMessageReceived;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  WebSocketService({required this.onMessageReceived});

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await AuthService.getToken();
    if (token == null) {
      print('[WebSocket] No auth token found, cannot connect.');
      return;
    }

        final uri = Uri.parse('$websocketUrl/ws/notifications/?token=$token');

    try {
      _channel = IOWebSocketChannel.connect(uri);
      _isConnected = true;
      print('[WebSocket] Connected successfully.');

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            onMessageReceived(data);
          } catch (e) {
            print('[WebSocket] Error parsing message: $e');
          }
        },
        onDone: () {
          print('[WebSocket] Disconnected.');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          print('[WebSocket] Error: $error');
          _isConnected = false;
          _channel!.sink.close();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print('[WebSocket] Connection error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) _reconnectTimer!.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('[WebSocket] Reconnecting...');
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    print('[WebSocket] Manually disconnected.');
  }
}
