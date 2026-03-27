class Order {
  final int id;
  final String category;
  final String fromAddress;
  final String toAddress;
  final double? fromLatitude;
  final double? fromLongitude;
  final double? toLatitude;
  final double? toLongitude;
  final double distance;
  final String status; // pending, accepted, in_transit, completed, cancelled
  final String description;
  final double? estimatedPrice;
  final String? courierName;
  final String? courierPhone;
  final int? courierId;
  final String? userName;
  final String? userPhone;
  final int? userId;
  final String createdAt;
  final String? verificationCode;
  final double? courierLatitude;
  final double? courierLongitude;

  Order({
    required this.id,
    required this.category,
    required this.fromAddress,
    required this.toAddress,
    this.fromLatitude,
    this.fromLongitude,
    this.toLatitude,
    this.toLongitude,
    required this.distance,
    required this.status,
    required this.description,
    this.estimatedPrice,
    this.courierName,
    this.courierPhone,
    this.courierId,
    this.userName,
    this.userPhone,
    this.userId,
    required this.createdAt,
    this.verificationCode,
    this.courierLatitude,
    this.courierLongitude,
  });

  String get categoryName {
    switch (category.toLowerCase()) {
      case 'food':
        return 'Тамак-аш';
      case 'groceries':
        return 'Азык-түлүк';
      case 'pharmacy':
        return 'Дарыкана';
      case 'clothes':
        return 'Кийим-кече';
      case 'electronics':
        return 'Электроника';
      case 'flowers':
        return 'Гүлдөр';
      case 'documents':
        return 'Документтер';
      case 'other':
        return 'Башка';
      default:
        return category;
    }
  }

  /// Create a copy of this order with some fields replaced
  Order copyWith({
    int? id,
    String? category,
    String? fromAddress,
    String? toAddress,
    double? fromLatitude,
    double? fromLongitude,
    double? toLatitude,
    double? toLongitude,
    double? distance,
    String? status,
    String? description,
    double? estimatedPrice,
    String? courierName,
    String? courierPhone,
    int? courierId,
    String? userName,
    String? userPhone,
    int? userId,
    String? createdAt,
    String? verificationCode,
    double? courierLatitude,
    double? courierLongitude,
  }) {
    return Order(
      id: id ?? this.id,
      category: category ?? this.category,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromLatitude: fromLatitude ?? this.fromLatitude,
      fromLongitude: fromLongitude ?? this.fromLongitude,
      toLatitude: toLatitude ?? this.toLatitude,
      toLongitude: toLongitude ?? this.toLongitude,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      description: description ?? this.description,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      courierName: courierName ?? this.courierName,
      courierPhone: courierPhone ?? this.courierPhone,
      courierId: courierId ?? this.courierId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      verificationCode: verificationCode ?? this.verificationCode,
      courierLatitude: courierLatitude ?? this.courierLatitude,
      courierLongitude: courierLongitude ?? this.courierLongitude,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString();
    final normalizedStatus = switch (rawStatus.toUpperCase()) {
      'WAITING_COURIER' => 'pending',
      'ACCEPTED' => 'accepted',
      'READY' => 'ready',
      'IN_TRANSIT' => 'in_transit',
      'ON_THE_WAY' => 'in_transit',
      'PICKED_UP' => 'picked_up',
      'DELIVERED' => 'delivered',
      'COMPLETED' => 'completed',
      'CANCELLED' => 'cancelled',
      _ => rawStatus.toLowerCase(),
    };

    final courier = json['courier'];
    final user = json['user'];

    return Order(
      id: json['id'] ?? 0,
      category: (json['category'] ?? 'other').toString(),
      fromAddress: json['from_address'] ?? '',
      toAddress: json['to_address'] ?? '',
      fromLatitude: (json['from_latitude'] as num?)?.toDouble(),
      fromLongitude: (json['from_longitude'] as num?)?.toDouble(),
      toLatitude: (json['to_latitude'] as num?)?.toDouble(),
      toLongitude: (json['to_longitude'] as num?)?.toDouble(),
      distance: (json['distance_km'] ?? json['distance'] ?? 0).toDouble(),
      status: normalizedStatus.isEmpty ? 'pending' : normalizedStatus,
      description: json['description'] ?? '',
      estimatedPrice: (json['price'] ?? json['estimated_price']) != null
          ? ((json['price'] ?? json['estimated_price']) as num).toDouble()
          : null,
      courierName: courier?['name'],
      courierPhone: courier?['phone'],
      courierId: courier?['id'],
      userName: user?['name'],
      userPhone: user?['phone'],
      userId: user?['id'],
      createdAt: (json['created_at'] ?? '').toString(),
      verificationCode: json['verification_code'],
      courierLatitude: (json['courier_latitude'] as num?)?.toDouble(),
      courierLongitude: (json['courier_longitude'] as num?)?.toDouble(),
    );
  }
}
