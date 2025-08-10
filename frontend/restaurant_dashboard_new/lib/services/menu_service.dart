import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:restaurant_dashboard_new/models/menu_category.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';

class MenuService {
  final String _baseUrl = 'http://127.0.0.1:8000/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<MenuItem>> getMenu() async {
    final token = await _getToken();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final response = await http.get(
      Uri.parse('$_baseUrl/restaurants/dashboard-menu/?_=$cacheBuster'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      // The API returns a direct list of menu items.
      final List<dynamic> itemsJson = jsonDecode(response.body);
      return itemsJson.map((json) => MenuItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get menu: ${response.body}');
    }
  }

  Future<List<MenuCategory>> getMenuCategories() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/menu-categories/'), // Corrected endpoint
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      // The API returns a direct list of categories.
      final List<dynamic> categoryList = jsonDecode(response.body);
      return categoryList.map((json) => MenuCategory.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load menu categories');
    }
  }

  Future<http.Response> addMenuItem(String name, String description, double price, int categoryId) async {
    final token = await _getToken();
    var request = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/menu-items/'));

    request.headers['Authorization'] = 'Token $token';

    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();
    request.fields['category'] = categoryId.toString();

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return response;
    } else {
      throw Exception('Failed to add menu item: ${response.body}');
    }
  }

  Future<http.Response> updateMenuItem(int id, String name, String description, double price, bool isAvailable) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/menu/items/$id/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'description': description,
        'price': price.toString(),
        'is_available': isAvailable,
      }),
    );

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Failed to update menu item: ${response.body}');
    }
  }

  Future<http.Response> deleteMenuItem(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/menu/items/$id/'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 204) {
      return response;
    } else {
      throw Exception('Failed to delete menu item: ${response.body}');
    }
  }

    Future<void> addMenuCategory(String name) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/menu-categories/');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Token $token',
    };
    final body = jsonEncode(<String, String>{'name': name});

    developer.log('Attempting to add category: $name', name: 'MenuService.addMenuCategory');
    developer.log('URL: $url', name: 'MenuService.addMenuCategory');
    developer.log('Headers: $headers', name: 'MenuService.addMenuCategory');
    developer.log('Body: $body', name: 'MenuService.addMenuCategory');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      developer.log('Response status: ${response.statusCode}', name: 'MenuService.addMenuCategory');
      developer.log('Response body: ${response.body}', name: 'MenuService.addMenuCategory');

      if (response.statusCode != 201) {
        throw Exception('Failed to add menu category: ${response.body}');
      }
    } catch (e) {
      developer.log('Error adding menu category: $e', name: 'MenuService.addMenuCategory', error: e);
      throw Exception('Failed to add menu category: $e');
    }
  }

  Future<void> updateMenuCategory(int id, String name) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/menu-categories/$id/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(<String, String>{
        'name': name,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update menu category: ${response.body}');
    }
  }

  Future<void> deleteMenuCategory(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/menu-categories/$id/'),
      headers: <String, String>{
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete menu category: ${response.body}');
    }
  }
}
