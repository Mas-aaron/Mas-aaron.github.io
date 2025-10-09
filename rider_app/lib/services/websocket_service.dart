import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rider_app/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final Function(Map<String, dynamic>) onMessageReceived;

  WebSocketService({required this.onMessageReceived});

  void connect(String token) {
    try {
      // Construct the final URL by appending the path and token to the base WebSocket URL.
      final String finalWsUrl = '$webSocketUrl/ws/rider/available_orders/?token=$token';
      final Uri websocketUri = Uri.parse(finalWsUrl);

      _channel = WebSocketChannel.connect(websocketUri);

      print('[WebSocket] Attempting to connect to $websocketUri');

      _channel!.stream.listen(
        (message) {
          print('[WebSocket Received Raw]: $message');
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;

            onMessageReceived(data);
          } catch (e) {
            print('[WebSocket Error] Failed to decode or process message: $e');
          }
        },
        onDone: () {
          print('WebSocket connection closed.');
        },
        onError: (error) {
          print('WebSocket error: $error');
          // Don't throw - just log the error
        },
      );
    } catch (e) {
      print('[WebSocket] Failed to connect: $e');
      // Don't throw - just log the error
    }
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      final message = jsonEncode(data);
      print('Sending WebSocket message: $message');
      _channel!.sink.add(message);
    } else {
      print('Cannot send message: WebSocket is not connected.');
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
