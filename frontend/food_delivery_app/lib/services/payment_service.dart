import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/payment.dart';

class PaymentService {
  final String _baseUrl = baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  String _paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mtnMobileMoney:
        return 'mtn_mobile_money';
      case PaymentMethod.airtelMoney:
        return 'airtel_money';
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
      case PaymentMethod.pesapal:
        return 'pesapal';
    }
  }

  /// Initiate a Pesapal payment
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    String? phoneNumber,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/payments/initiate/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'order_id': orderId,
          'payment_method': _paymentMethodToString(paymentMethod),
          'amount': amount.toString(),
          if (phoneNumber != null) 'phone_number': phoneNumber,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': data['success'] ?? true,
          'payment_id': data['payment_id'],
          'reference': data['reference'],
          'redirect_url': data['redirect_url'],
          'message': data['message'] ?? 'Payment initiated successfully',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to initiate payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/payments/status/$paymentId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': data['status'],
          'payment_method': data['payment_method'],
          'amount': data['amount'],
          'currency': data['currency'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to check payment status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get payment history for user
  Future<List<Payment>> getPaymentHistory() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/payments/history/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Payment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load payment history');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Cancel a pending payment
  Future<Map<String, dynamic>> cancelPayment(String paymentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/payments/$paymentId/cancel/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Payment cancelled successfully',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to cancel payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

}
