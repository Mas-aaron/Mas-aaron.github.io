import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:restaurant_dashboard_new/models/bill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/constants.dart';

class BillService {
  Future<List<Bill>> fetchBills() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/bills/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<Bill> bills = body.map((dynamic item) => Bill.fromJson(item)).toList();
      return bills;
    } else {
      throw Exception('Failed to load bills');
    }
  }
}
