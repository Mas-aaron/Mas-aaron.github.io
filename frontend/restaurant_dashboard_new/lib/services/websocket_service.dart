import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';

const String _baseUrl = kIsWeb ? 'localhost:8000' : '10.0.2.2:8000';

class WebSocketService {
  WebSocketChannel? _channel;
  final Function(List<Order>) onInitialOrders;
  final Function(Order) onNewOrder;
  final Function(Order) onOrderUpdate;
  bool _isConnected = false;

  WebSocketService({
    required this.onInitialOrders,
    required this.onNewOrder,
    required this.onOrderUpdate,
  });

  Future<void> connect() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      debugPrint('Authentication token not found.');
      return;
    }

    final wsUrl = 'ws://$_baseUrl/ws/restaurant/orders/?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      debugPrint('WebSocket connected to $wsUrl');

      _channel!.stream.listen(_handleMessage, onDone: () {
        _isConnected = false;
        debugPrint('WebSocket disconnected.');
      }, onError: (error) {
        _isConnected = false;
        debugPrint('WebSocket error: $error');
      });

      // Subscribe to orders after connecting
      _channel!.sink.add(jsonEncode({'type': 'subscribe_orders'}));
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'];
      final ordersData = message['orders'] as List<dynamic>? ?? [];

            List<Order> orders = ordersData.map((o) => Order.fromJson(o)).toList();

      switch (type) {
        case 'initial_orders':
          onInitialOrders(orders);
          break;
        case 'new_orders':
          if (orders.isNotEmpty) onNewOrder(orders.first);
          break;
        case 'order_updates':
          if (orders.isNotEmpty) onOrderUpdate(orders.first);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _isConnected = false;
    }
  }
}
