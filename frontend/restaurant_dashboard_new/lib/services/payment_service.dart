import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_models.dart';
import '../constants.dart';

class PaymentService {
  Future<List<PaymentPeriod>> getPaymentPeriods() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/payment-periods/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaymentPeriod.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load payment periods. Status code: ${response.statusCode}');
    }
  }

  Future<PaymentPeriod> getCurrentWeekPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/payment-periods/current_week/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return PaymentPeriod.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load current week period. Status code: ${response.statusCode}');
    }
  }

  Future<List<OrderPayment>> getOrderPayments({int? periodId, String? startDate, String? endDate}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    String url = '$baseUrl/order-payments/';
    List<String> queryParams = [];
    
    if (periodId != null) {
      queryParams.add('period_id=$periodId');
    }
    if (startDate != null) {
      queryParams.add('start_date=$startDate');
    }
    if (endDate != null) {
      queryParams.add('end_date=$endDate');
    }
    
    if (queryParams.isNotEmpty) {
      url += '?' + queryParams.join('&');
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => OrderPayment.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load order payments. Status code: ${response.statusCode}');
    }
  }

  Future<List<BankAccount>> getBankAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/bank-accounts/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BankAccount.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load bank accounts. Status code: ${response.statusCode}');
    }
  }

  Future<BankAccount> createBankAccount({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    String? routingNumber,
    String? swiftCode,
    required String accountType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/bank-accounts/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'account_holder_name': accountHolderName,
        'bank_name': bankName,
        'account_number': accountNumber,
        'routing_number': routingNumber,
        'swift_code': swiftCode,
        'account_type': accountType,
      }),
    );

    if (response.statusCode == 201) {
      return BankAccount.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create bank account. Status code: ${response.statusCode}');
    }
  }

  Future<List<PaymentDispute>> getPaymentDisputes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/payment-disputes/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PaymentDispute.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load payment disputes. Status code: ${response.statusCode}');
    }
  }

  Future<PaymentDispute> respondToDispute(int disputeId, String response) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final httpResponse = await http.post(
      Uri.parse('$baseUrl/payment-disputes/$disputeId/respond/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'response': response,
      }),
    );

    if (httpResponse.statusCode == 200) {
      return PaymentDispute.fromJson(jsonDecode(httpResponse.body));
    } else {
      throw Exception('Failed to respond to dispute. Status code: ${httpResponse.statusCode}');
    }
  }
}
