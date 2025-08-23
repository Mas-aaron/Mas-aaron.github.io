import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/loyalty/loyalty_profile.dart';
import '../models/loyalty/reward.dart';
import '../models/loyalty/points_transaction.dart';

class LoyaltyService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<LoyaltyProfile> getLoyaltyProfile() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/loyalty/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return LoyaltyProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load loyalty profile');
    }
  }

  Future<List<Reward>> getAvailableRewards() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/loyalty/rewards/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Reward.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  Future<Map<String, dynamic>> redeemReward(int rewardId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/loyalty/redeem/$rewardId/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to redeem reward');
    }
  }

  Future<List<PointsTransaction>> getTransactionHistory() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/loyalty/transactions/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => PointsTransaction.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load transaction history');
    }
  }
}
