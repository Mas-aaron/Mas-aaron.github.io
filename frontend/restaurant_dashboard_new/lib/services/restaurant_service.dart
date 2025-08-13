import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_dashboard_new/models/restaurant.dart';
import 'package:restaurant_dashboard_new/models/restaurant_review.dart';
import '../constants.dart';

class RestaurantService {
  final String _apiBaseUrl = baseUrl;

  Future<Restaurant> getRestaurantProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/profile/restaurant/'),
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

  Future<Restaurant> updateRestaurantProfile(
    int restaurantId,
    String name,
    String address,
    String phoneNumber,
    String email,
    XFile? imageFile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_apiBaseUrl/profile/restaurant/'),
    );

    request.headers['Authorization'] = 'Token $token';
    request.fields['name'] = name;
    request.fields['address'] = address;
    request.fields['phone_number'] = phoneNumber;
    request.fields['email'] = email;

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: imageFile.name,
      );
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Restaurant.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update restaurant profile: ${response.body}');
    }
  }

    Future<List<RestaurantReview>> fetchRestaurantReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Authentication token not found');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/restaurant/dashboard-reviews/'),
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
      Uri.parse('$_apiBaseUrl/restaurant/dashboard-reviews/$reviewId/reply/'),
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
