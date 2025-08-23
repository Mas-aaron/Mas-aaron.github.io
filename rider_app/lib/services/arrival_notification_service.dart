import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/order.dart';

class ArrivalNotificationService {
  static final ArrivalNotificationService _instance = 
      ArrivalNotificationService._internal();
  factory ArrivalNotificationService() => _instance;
  ArrivalNotificationService._internal();

  Future<bool> triggerArrivalNotification(Order order, double latitude, double longitude) async {
    try {
      // Send arrival notification to backend
      final success = await _sendArrivalToBackend(order, latitude, longitude);
      
      if (success) {
        // Vibrate device for feedback
        HapticFeedback.mediumImpact();
        print('Customer notified of arrival successfully');
        return true;
      }
      
      return false;
      
    } catch (error) {
      print('Arrival notification error: $error');
      return false;
    }
  }

  Future<bool> _sendArrivalToBackend(Order order, double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider-orders/${order.id}/arrival/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${await _getAuthToken()}',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Arrival notification sent: ${data['message']}');
        return true;
      } else {
        final error = json.decode(response.body);
        print('Arrival notification failed: ${error['error']}');
        
        if (error['error'].toString().contains('not close enough')) {
          print('Too far from customer: need to be within ${error['required_distance']}m, currently ${error['distance']?.toStringAsFixed(1)}m away');
        } else {
          print('Arrival notification error: ${error['error']}');
        }
        return false;
      }
    } catch (error) {
      print('Network error sending arrival notification: $error');
      return false;
    }
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  // Method to manually trigger arrival notification
  Future<bool> manualArrivalConfirmation(Order order, double latitude, double longitude) async {
    return await triggerArrivalNotification(order, latitude, longitude);
  }
}
