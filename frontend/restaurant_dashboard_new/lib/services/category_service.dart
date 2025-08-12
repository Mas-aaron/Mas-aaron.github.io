import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_category.dart';


const String backendUrl = 'http://10.4.45.57:8000';

class CategoryService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<MenuCategory>> getCategories() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$backendUrl/api/menu-categories/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MenuCategory.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<MenuCategory> createCategory(String name) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$backendUrl/api/menu-categories/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'name': name,
      }),
    );

    if (response.statusCode == 201) {
      return MenuCategory.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create category.');
    }
  }

  Future<void> updateCategory(int id, String name) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$backendUrl/api/menu-categories/$id/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'name': name,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update category.');
    }
  }

  Future<void> deleteCategory(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$backendUrl/api/menu-categories/$id/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete category.');
    }
  }
}
