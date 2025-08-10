import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/models/restaurant.dart';
import 'package:restaurant_dashboard_new/models/restaurant_review.dart';

class RestaurantService {
  final String _baseUrl = 'http://127.0.0.1:8000/api';

  Future<Restaurant> getRestaurantProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/profile/restaurant/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return Restaurant.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load restaurant profile');
    }
  }

  Future<Restaurant> updateRestaurantProfile(Restaurant restaurant) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/profile/restaurant/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(restaurant.toJson()),
    );

    if (response.statusCode == 200) {
      return Restaurant.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update restaurant profile');
    }
  }

    Future<List<RestaurantReview>> fetchRestaurantReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/restaurant/dashboard-reviews/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<RestaurantReview> reviews =
          body.map((dynamic item) => RestaurantReview.fromJson(item)).toList();
      return reviews;
    } else {
      throw Exception('Failed to load restaurant reviews');
    }
  }

  Future<RestaurantReview> replyToReview(int reviewId, String replyText) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/restaurant/dashboard-reviews/$reviewId/reply/'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'reply_text': replyText}),
    );

    if (response.statusCode == 200) {
      return RestaurantReview.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to reply to review');
    }
  }
}
