class Restaurant {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String email;
  final String orderProtocol;
  final String? image;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
    required this.orderProtocol,
    this.image,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'No Name Provided',
      address: json['address'] ?? 'No Address Provided',
      phoneNumber: json['phone_number'] ?? 'No Phone Provided',
      email: json['email'] ?? 'No Email Provided',
      orderProtocol: json['order_protocol'] ?? 'http',
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'email': email,
      'order_protocol': orderProtocol,
      'image': image,
    };
  }
}
