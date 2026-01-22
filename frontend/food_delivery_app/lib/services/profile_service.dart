import 'dart:convert';
import 'package:food_delivery_app/constants.dart';
import 'package:food_delivery_app/models/customer_profile.dart';
import 'package:food_delivery_app/models/dietary_preference.dart';
import 'package:food_delivery_app/models/user_address.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  final String _baseUrl = baseUrl;

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<CustomerProfile> getCustomerProfile() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/profile/customer/'), headers: headers);

    if (response.statusCode == 200) {
      return CustomerProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer profile');
    }
  }

  Future<void> deleteCurrentUser() async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/me/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete account');
    }
  }

  Future<ProfileUser> updateCurrentUser({String? username, String? email}) async {
    final headers = await _getAuthHeaders();
    final body = <String, dynamic>{};
    if (username != null) {
      body['username'] = username;
    }
    if (email != null) {
      body['email'] = email;
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/me/'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return ProfileUser.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update user');
    }
  }

  Future<CustomerProfile> updateCustomerProfile(List<int> dietaryPreferenceIds) async {
    final headers = await _getAuthHeaders();
    final body = jsonEncode({'dietary_preference_ids': dietaryPreferenceIds});
    final response = await http.patch(Uri.parse('$_baseUrl/profile/customer/'), headers: headers, body: body);

    if (response.statusCode == 200) {
      return CustomerProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update customer profile');
    }
  }

  Future<List<UserAddress>> getAddresses() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/addresses/'), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => UserAddress.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load addresses');
    }
  }

  Future<UserAddress> addAddress(UserAddress address) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/addresses/'), headers: headers, body: jsonEncode(address.toJson()));

    if (response.statusCode == 201) {
      return UserAddress.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add address');
    }
  }

  Future<UserAddress> updateAddress(int addressId, UserAddress address) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(Uri.parse('$_baseUrl/addresses/$addressId/'), headers: headers, body: jsonEncode(address.toJson()));

    if (response.statusCode == 200) {
      return UserAddress.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update address');
    }
  }

  Future<void> deleteAddress(int addressId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/addresses/$addressId/'), headers: headers);

    if (response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }

  Future<List<DietaryPreference>> getDietaryPreferences() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/dietary-preferences/'), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => DietaryPreference.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load dietary preferences');
    }
  }
}
