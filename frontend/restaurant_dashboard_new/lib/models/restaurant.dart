class Restaurant {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String email;
  final String orderProtocol;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
    required this.orderProtocol,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      orderProtocol: json['order_protocol'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'email': email,
      'order_protocol': orderProtocol,
    };
  }
}
