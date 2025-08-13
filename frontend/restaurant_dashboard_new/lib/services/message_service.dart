import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/models/message.dart';
import '../constants.dart';

class MessageService {
  Future<List<Message>> getMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/messages/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Message> messages = body.map((dynamic item) => Message.fromJson(item)).toList();
      return messages;
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<Message> sendMessage(int recipientId, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/messages/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'recipient': recipientId,
        'content': content,
      }),
    );

    if (response.statusCode == 201) { // 201 Created
      final data = jsonDecode(response.body);
      return Message.fromJson(data);
    } else {
      throw Exception('Failed to send message');
    }
  }
}
