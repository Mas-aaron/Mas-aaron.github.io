import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:restaurant_dashboard_new/models/analytics_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/constants.dart';

class AnalyticsService {
  Future<AnalyticsData> getAnalyticsData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard-analytics/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return AnalyticsData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load analytics data. Status code: ${response.statusCode}');
    }
  }
}
