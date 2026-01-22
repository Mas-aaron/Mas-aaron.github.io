import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class PromoCodeDto {
  final int? id;
  final String code;
  final String discountType;
  final String discountValue;
  final bool? isActive;
  final int? maxUses;
  final int? perUserLimit;
  final String? startsAt;
  final String? expiresAt;

  PromoCodeDto({
    this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.isActive,
    this.maxUses,
    this.perUserLimit,
    this.startsAt,
    this.expiresAt,
  });

  factory PromoCodeDto.fromJson(Map<String, dynamic> json) {
    return PromoCodeDto(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      code: json['code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : null,
      maxUses: json['max_uses'] is int ? json['max_uses'] as int : int.tryParse(json['max_uses']?.toString() ?? ''),
      perUserLimit: json['per_user_limit'] is int ? json['per_user_limit'] as int : int.tryParse(json['per_user_limit']?.toString() ?? ''),
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
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => PromoCodeDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    throw Exception('Failed to load promo codes');
  }

  Future<List<PromoCodeDto>> listMyPromoCodes() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/restaurant/promo-codes/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((e) => PromoCodeDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    throw Exception('Failed to load your promo codes');
  }

  Future<PromoCodeDto> createMyPromoCode({
    required String code,
    required String discountType,
    required String discountValue,
    int? maxUses,
    int? perUserLimit,
    String? startsAt,
    String? expiresAt,
    bool isActive = true,
  }) async {
    final headers = await _getAuthHeaders();
    final payload = <String, dynamic>{
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'is_active': isActive,
    };
    if (maxUses != null) payload['max_uses'] = maxUses;
    if (perUserLimit != null) payload['per_user_limit'] = perUserLimit;
    if (startsAt != null && startsAt.isNotEmpty) payload['starts_at'] = startsAt;
    if (expiresAt != null && expiresAt.isNotEmpty) payload['expires_at'] = expiresAt;

    final response = await http.post(
      Uri.parse('$_baseUrl/restaurant/promo-codes/'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      return PromoCodeDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map) {
        throw Exception(parsed.toString());
      }
    } catch (_) {}

    throw Exception('Failed to create promo code');
  }

  Future<PromoCodeDto> updateMyPromoCode({
    required int promoId,
    bool? isActive,
  }) async {
    final headers = await _getAuthHeaders();
    final payload = <String, dynamic>{};
    if (isActive != null) payload['is_active'] = isActive;

    final response = await http.patch(
      Uri.parse('$_baseUrl/restaurant/promo-codes/$promoId/'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return PromoCodeDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map) {
        throw Exception(parsed.toString());
      }
    } catch (_) {}

    throw Exception('Failed to update promo code');
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
