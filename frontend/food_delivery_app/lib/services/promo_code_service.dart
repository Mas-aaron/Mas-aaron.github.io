import 'dart:convert';

import 'package:food_delivery_app/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PromoCodeDto {
  final String code;
  final String discountType;
  final String discountValue;
  final String? startsAt;
  final String? expiresAt;

  PromoCodeDto({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.startsAt,
    this.expiresAt,
  });

  factory PromoCodeDto.fromJson(Map<String, dynamic> json) {
    return PromoCodeDto(
      code: json['code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
      startsAt: json['starts_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class AppliedPromoCodeDto {
  final String code;
  final String discountType;
  final String discountValue;

  AppliedPromoCodeDto({
    required this.code,
    required this.discountType,
    required this.discountValue,
  });

  factory AppliedPromoCodeDto.fromJson(Map<String, dynamic> json) {
    return AppliedPromoCodeDto(
      code: json['code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
    );
  }
}

class PromoCodeService {
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

  Future<List<PromoCodeDto>> listPromoCodes() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/promo-codes/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) {
        return body
            .map((e) => PromoCodeDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    throw Exception('Failed to load promo codes');
  }

  Future<AppliedPromoCodeDto> applyPromoCode(String code) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/promo-codes/apply/'),
      headers: headers,
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode == 200) {
      return AppliedPromoCodeDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map && parsed['error'] != null) {
        throw Exception(parsed['error'].toString());
      }
    } catch (_) {}

    throw Exception('Failed to apply promo code');
  }
}
