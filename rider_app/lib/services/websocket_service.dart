import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rider_app/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final Function(Map<String, dynamic>) onMessageReceived;

  WebSocketService({required this.onMessageReceived});

  void connect(String token) {
    final String wsUrl = webSocketUrl.replaceFirst('http', 'ws');
    final Uri websocketUri = Uri.parse('$wsUrl/ws/notifications/?token=$token');
    _channel = WebSocketChannel.connect(websocketUri);

    print('[WebSocket] Attempting to connect to $websocketUri');

    _channel!.stream.listen(
      (message) {
        print('[WebSocket Received Raw]: $message');
        try {
          final data = jsonDecode(message) as Map<String, dynamic>;

          // Normalize message type for consistency
          if (data['type'] == 'new_order') {
            data['type'] = 'new.order';
            print("[WebSocket Normalized]: Type to 'new.order'");
          }
          
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
      },
    );
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
