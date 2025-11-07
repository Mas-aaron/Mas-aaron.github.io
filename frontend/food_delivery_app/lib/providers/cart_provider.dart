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
  String? _tableNumber;

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Order type getters
  OrderType get orderType => _orderType;
  DateTime? get scheduledTime => _scheduledTime;
  double get tipAmount => _tipAmount;
  String? get tableNumber => _tableNumber;
  
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
  
  void setTableNumber(String? number) {
    _tableNumber = number;
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
      // Update backend and get new cart item
      await _apiService.updateCartItemQuantity(cartItemId, quantity);
      
      // Update locally for instant UI response
      if (_cart != null) {
        final itemIndex = _cart!.items.indexWhere((item) => item.id == cartItemId);
        if (itemIndex != -1) {
          // Fetch just updated cart to get correct data
          await fetchCart();
        }
      }
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
    // Don't show global loading - update optimistically
    bool success = false;
    try {
      final newCartItem = await _apiService.addToCart(menuItemId, 1);
      
      // Update cart locally IMMEDIATELY for instant UI response
      if (_cart != null) {
        // Check if item already exists in cart
        final existingItemIndex = _cart!.items.indexWhere(
          (item) => item.menuItem?.id == menuItemId
        );
        
        if (existingItemIndex != -1) {
          // Update existing item quantity
          _cart!.items[existingItemIndex] = newCartItem;
        } else {
          // Add new item
          _cart!.items.add(newCartItem);
        }
        
        // Recalculate is handled by Cart model getter
        // Notify immediately for instant UI update
        notifyListeners();
      } else {
        // If cart is null, fetch it once
        _isLoading = true;
        notifyListeners();
        await fetchCart();
        _isLoading = false;
      }
      
      _error = null;
      success = true;
    } catch (e) {
      _error = 'Failed to add item to cart: $e';
      success = false;
      notifyListeners();
    }

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
      // For non-delivery orders, don't pass location data
      double? lat = _orderType == OrderType.delivery ? latitude : null;
      double? lng = _orderType == OrderType.delivery ? longitude : null;
      
      final order = await _apiService.placeOrder(
        address ?? '', 
        lat ?? 0.0, 
        lng ?? 0.0,
        orderType: _orderType,
        scheduledTime: _scheduledTime,
        tipAmount: _tipAmount,
        tableNumber: _tableNumber,
      );
      await fetchCart(); // Refresh cart, which should now be empty
      _isLoading = false;
      notifyListeners();
      return {'success': true, 'order_id': order.id};
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
