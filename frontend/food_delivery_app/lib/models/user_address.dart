class UserAddress {
  final int id;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String stateProvince;
  final String postalCode;
  final String country;
  final bool isDefault;

  UserAddress({
    required this.id,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.stateProvince,
    required this.postalCode,
    required this.country,
    required this.isDefault,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'],
      addressLine1: json['address_line_1'],
      addressLine2: json['address_line_2'],
      city: json['city'],
      stateProvince: json['state_province'],
      postalCode: json['postal_code'],
      country: json['country'],
      isDefault: json['is_default'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state_province': stateProvince,
      'postal_code': postalCode,
      'country': country,
      'is_default': isDefault,
    };
  }
}
