class User {
  final int id;
  final String phone;
  final String name;
  final bool isCourier;
  final bool isAdmin;
  final double balance;
  final String? address;
  final bool isOnline;
  final String uniqueId;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.isCourier,
    required this.isAdmin,
    required this.balance,
    this.address,
    this.isOnline = false,
    required this.uniqueId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      isCourier: json['is_courier'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      balance: (json['balance'] ?? 0).toDouble(),
      address: json['address'],
      isOnline: json['is_online'] ?? false,
      uniqueId: json['unique_id'] ?? '',
    );
  }
}
