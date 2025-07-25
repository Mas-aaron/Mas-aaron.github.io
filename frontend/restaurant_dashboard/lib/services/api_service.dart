import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';

class ApiService {
  final String baseUrl;
  final String? authToken;
  ApiService({required this.baseUrl, this.authToken});

  Map<String, String> get _headers => {
    'Authorization': 'Token ${authToken ?? ''}',
    'Content-Type': 'application/json',
  };

  Future<List<dynamic>> fetchMenuItems(int restaurantId) async {
    final url = Uri.parse('$baseUrl/restaurants/$restaurantId/menu-items/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception('Failed to fetch menu items');
    }
  }

  Future<List<dynamic>> fetchModifierGroups() async {
    final url = Uri.parse('$baseUrl/modifier-groups/');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception('Failed to fetch modifier groups');
    }
  }

  Future<Map<String, dynamic>> uploadMenuCsv({
    required int restaurantId, required File file
  }) async {
    final url = Uri.parse('$baseUrl/menu-items/bulk-upload/');
    var request = http.MultipartRequest('POST', url)
      ..fields['restaurant_id'] = restaurantId.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'file', file.path,
        contentType: MediaType('text', 'csv'),
      ));
    if (authToken != null) {
      request.headers['Authorization'] = 'Token $authToken';
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('CSV upload failed: ${response.body}');
    }
  }

  Future<void> updateMenuItem({
    required int restaurantId,
    required int menuItemId,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('$baseUrl/restaurants/$restaurantId/menu-items/$menuItemId/');
    final res = await http.patch(url, headers: _headers, body: json.encode(data));
    if (res.statusCode != 200) {
      throw Exception('Failed to update menu item: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> createModifierGroup(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/modifier-groups/');
    final res = await http.post(url, headers: _headers, body: json.encode(data));
    if (res.statusCode == 201) {
      return json.decode(res.body);
    } else {
      throw Exception('Failed to create modifier group: ${res.body}');
    }
  }

  Future<void> updateModifierGroup(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/modifier-groups/$id/');
    final res = await http.patch(url, headers: _headers, body: json.encode(data));
    if (res.statusCode != 200) {
      throw Exception('Failed to update modifier group: ${res.body}');
    }
  }

  Future<void> deleteModifierGroup(int id) async {
    final url = Uri.parse('$baseUrl/modifier-groups/$id/');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode != 204) {
      throw Exception('Failed to delete modifier group: ${res.body}');
    }
  }

  // Add more methods for modifier CRUD if needed.

  Future<void> createMenuItem({
    required int restaurantId,
    required Map<String, dynamic> data,
    File? imageFile,
  }) async {
    if (imageFile != null) {
      final url = Uri.parse('$baseUrl/menu-items/create/');
      var request = http.MultipartRequest('POST', url);
      request.fields['restaurant'] = restaurantId.toString();
      data.forEach((key, value) {
        if (value != null) {
          if (value is List) {
            for (var v in value) {
              request.fields['$key[]'] = v.toString();
            }
          } else {
            request.fields[key] = value.toString();
          }
        }
      });
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      if (authToken != null) {
        request.headers['Authorization'] = 'Token $authToken';
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 201) {
        throw Exception('Failed to create menu item: ${response.body}');
      }
    } else {
      final url = Uri.parse('$baseUrl/restaurants/$restaurantId/menu-items/');
      final res = await http.post(url, headers: _headers, body: json.encode(data));
      if (res.statusCode != 201) {
        throw Exception('Failed to create menu item: ${res.body}');
      }
    }
  }
}

