import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart.dart';
import '../widgets/order_type_selector.dart';

import '../constants.dart';
import '../services/api_service.dart';

class CartProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Cart? _cart;
  bool _isLoading = false;
  String? _error;
  
  // Order type and scheduling for dine-in
  OrderType _orderType = OrderType.delivery;
  DateTime? _scheduledTime;
  double _tipAmount = 0.0;

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Order type getters
  OrderType get orderType => _orderType;
  DateTime? get scheduledTime => _scheduledTime;
  double get tipAmount => _tipAmount;
  
  // Order type setters
  void setOrderType(OrderType type) {
    _orderType = type;
    if (type != OrderType.dineIn) {
      _scheduledTime = null;
    }
    notifyListeners();
  }
  
  void setScheduledTime(DateTime? time) {
    _scheduledTime = time;
    notifyListeners();
  }
  
  void setTipAmount(double amount) {
    _tipAmount = amount;
    notifyListeners();
  }



  Future<void> fetchCart() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _error = 'Authentication token not found.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cart = Cart.fromJson(data);
        _error = null;
        notifyListeners(); // Notify listeners immediately with new cart data
      } else {
        _error = 'Failed to load cart. Status code: ${response.statusCode}';
        _cart = null;
      }
    } catch (e) {
      _error = 'An error occurred while fetching the cart: $e';
      _cart = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateItemQuantity(int cartItemId, int quantity) async {
    try {
      await _apiService.updateCartItemQuantity(cartItemId, quantity);
      await fetchCart();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeItem(int cartItemId) async {
    try {
      await _apiService.removeCartItem(cartItemId);
      await fetchCart();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addToCart(int menuItemId) async {
    _isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      await _apiService.addToCart(menuItemId, 1); // Use ApiService
      await fetchCart(); // Refresh cart state
      _error = null;
      success = true;
    } catch (e) {
      _error = 'Failed to add item to cart: $e';
      success = false;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> removeFromCart(int cartItemId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/remove/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Token $token',
        },
        body: json.encode({'cart_item_id': cartItemId}),
      );

      if (response.statusCode == 200) {
        await fetchCart(); // Refresh cart state
      } else {
        _error = 'Failed to remove item from cart.';
      }
    } catch (e) {
      _error = 'An error occurred while removing from cart: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

     _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/clear/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        _cart = null;
        await fetchCart();
      } else {
        _error = 'Failed to clear cart.';
      }
    } catch (e) {
      _error = 'An error occurred while clearing cart: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> placeOrder(String? address, double? latitude, double? longitude) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _error = 'You are not logged in.';
      notifyListeners();
      return {'success': false, 'error': 'You are not logged in.'};
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.placeOrder(
        address ?? '', 
        latitude ?? 0.0, 
        longitude ?? 0.0,
        orderType: _orderType,
        scheduledTime: _scheduledTime,
        tipAmount: _tipAmount,
      );
      await fetchCart(); // Refresh cart, which should now be empty
      _isLoading = false;
      notifyListeners();
      return {'success': true};
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // Remove "Exception: " prefix
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  }
}
