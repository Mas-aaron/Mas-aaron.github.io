import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:food_delivery_app/constants.dart';

class WebSocketTestScreen extends StatefulWidget {
  final int orderId;

  const WebSocketTestScreen({super.key, required this.orderId});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  WebSocketChannel? _channel;
  final List<String> _messages = [];
  bool _connected = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    // Close existing connection if any
    _channel?.sink.close();
    
    final urlString = '$webSocketUrl/ws/track/${widget.orderId}/';
    print('Test: Connecting to WebSocket: $urlString');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(urlString));
      print('Test: WebSocket channel created successfully');
      
      setState(() {
        _messages.add('${DateTime.now()}: Connecting to WebSocket...');
      });

      _channel!.stream.listen(
        (data) {
          print('Test: WebSocket received: $data');
          
          setState(() {
            _messages.add('${DateTime.now()}: Received: $data');
            _connected = true;
            _reconnectAttempts = 0; // Reset reconnect attempts on successful message
          });
          
          try {
            final decodedData = jsonDecode(data);
            setState(() {
              _messages.add('${DateTime.now()}: Decoded: $decodedData');
            });
          } catch (e) {
            setState(() {
              _messages.add('${DateTime.now()}: Error decoding: $e');
            });
          }
        },
        onDone: () {
          print('Test: WebSocket connection closed.');
          setState(() {
            _messages.add('${DateTime.now()}: Connection closed');
            _connected = false;
          });
          
          // Attempt to reconnect if needed
          _attemptReconnect();
        },
        onError: (error) {
          print('Test: WebSocket error: $error');
          setState(() {
            _messages.add('${DateTime.now()}: Error: $error');
            _connected = false;
          });
          
          // Attempt to reconnect if needed
          _attemptReconnect();
        },
        cancelOnError: true,
      );
      
      setState(() {
        _messages.add('${DateTime.now()}: WebSocket stream listener attached');
      });
      
    } catch (e) {
      print('Test: Error initializing WebSocket: $e');
      setState(() {
        _messages.add('${DateTime.now()}: Connection error: $e');
        _connected = false;
      });
      
      // Attempt to reconnect if needed
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts && !_connected) {
      setState(() {
        _reconnectAttempts++;
        _messages.add('${DateTime.now()}: Attempting to reconnect ($_reconnectAttempts/$_maxReconnectAttempts)');
      });
      
      // Wait 2 seconds before reconnecting
      Future.delayed(const Duration(seconds: 2), () {
        if (!_connected) {
          _initializeWebSocket();
        }
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        _messages.add('${DateTime.now()}: Max reconnect attempts reached. Giving up.');
      });
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket Test for Order #${widget.orderId}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _initializeWebSocket,
                  child: const Text('Reconnect'),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _connected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(_connected ? 'Connected' : 'Disconnected'),
                Text('Attempts: $_reconnectAttempts'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
