import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/order.dart'; // Assuming you have an Order model

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  final StreamController<List<Order>> _newOrdersController = StreamController<List<Order>>.broadcast();
  Stream<List<Order>> get newOrders => _newOrdersController.stream;

  final StreamController<List<Order>> _orderUpdatesController = StreamController<List<Order>>.broadcast();
  Stream<List<Order>> get orderUpdates => _orderUpdatesController.stream;

  void connect(String url) {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      debugPrint('WebSocket connected to $url');

      _channel!.stream.listen(
        (data) {
          _handleIncomingData(data);
        },
        onDone: () {
          _isConnected = false;
          debugPrint('WebSocket disconnected.');
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('WebSocket error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
    }
  }

  void _handleIncomingData(dynamic data) {
    try {
      final parsedData = jsonDecode(data);
      final type = parsedData['type'];

      if (type == 'new_orders' || type == 'initial_orders') {
        final ordersData = parsedData['orders'] as List;
        final orders = ordersData.map((item) => Order.fromJson(item)).toList();
        _newOrdersController.add(orders);
      } else if (type == 'order_updates') {
        final ordersData = parsedData['orders'] as List;
        final orders = ordersData.map((item) => Order.fromJson(item)).toList();
        _orderUpdatesController.add(orders);
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket data: $e');
    }
  }

  void dispose() {
    _newOrdersController.close();
    _orderUpdatesController.close();
    _channel?.sink.close();
    _isConnected = false;
  }
}
