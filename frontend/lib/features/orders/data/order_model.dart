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
  final String courierTransport;
  final String? courierVehiclePlate;
  final String? courierVehicleBrand;
  final String? courierVehicleColor;
  final String? userName;
  final String? userPhone;
  final int? userId;
  final String createdAt;
  final double? courierLatitude;
  final double? courierLongitude;
  final int? enterpriseId;
  final String? enterpriseName;
  final double? itemsTotal;
  final bool cancelRequested;
  final String source;
  final String orderType;
  final String? customerPhone;

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
    this.courierTransport = 'walking',
    this.courierVehiclePlate,
    this.courierVehicleBrand,
    this.courierVehicleColor,
    this.userName,
    this.userPhone,
    this.userId,
    required this.createdAt,
    this.courierLatitude,
    this.courierLongitude,
    this.enterpriseId,
    this.enterpriseName,
    this.itemsTotal,
    this.cancelRequested = false,
    this.source = 'online',
    this.orderType = 'delivery',
    this.customerPhone,
  });

  bool get isAdminExternal => source == 'admin_external';

  String get courierTransportLabel {
    switch (courierTransport) {
      case 'car':
        return 'Жеңил автоунаа';
      case 'cargo':
        return 'Жүк ташуучу автоунаа';
      case 'scooter':
        return 'Скутер';
      default:
        return 'Жөө';
    }
  }

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
      case 'household':
        return 'Үй-тиричилик буюмдары';
      case 'autoparts':
        return 'Унаа тетиктери';
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
    String? courierTransport,
    String? courierVehiclePlate,
    String? courierVehicleBrand,
    String? courierVehicleColor,
    String? userName,
    String? userPhone,
    int? userId,
    String? createdAt,
    double? courierLatitude,
    double? courierLongitude,
    int? enterpriseId,
    String? enterpriseName,
    double? itemsTotal,
    bool? cancelRequested,
    String? source,
    String? orderType,
    String? customerPhone,
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
      courierTransport: courierTransport ?? this.courierTransport,
      courierVehiclePlate: courierVehiclePlate ?? this.courierVehiclePlate,
      courierVehicleBrand: courierVehicleBrand ?? this.courierVehicleBrand,
      courierVehicleColor: courierVehicleColor ?? this.courierVehicleColor,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      courierLatitude: courierLatitude ?? this.courierLatitude,
      courierLongitude: courierLongitude ?? this.courierLongitude,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      enterpriseName: enterpriseName ?? this.enterpriseName,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      source: source ?? this.source,
      orderType: orderType ?? this.orderType,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString();
    final normalizedStatus = switch (rawStatus.toUpperCase()) {
      'WAITING_COURIER' => 'pending',
      'ACCEPTED' => 'accepted',
      'PREPARING' => 'preparing',
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
      courierTransport:
          (courier?['transport'] ?? json['courier_transport'] ?? 'walking')
              .toString(),
      courierVehiclePlate:
          courier?['vehicle_plate']?.toString() ??
          json['courier_vehicle_plate']?.toString(),
      courierVehicleBrand:
          courier?['vehicle_brand']?.toString() ??
          json['courier_vehicle_brand']?.toString(),
      courierVehicleColor:
          courier?['vehicle_color']?.toString() ??
          json['courier_vehicle_color']?.toString(),
      userName: user?['name'],
      userPhone: json['customer_phone']?.toString() ?? user?['phone'],
      userId: user?['id'],
      createdAt: (json['created_at'] ?? '').toString(),
      courierLatitude: (json['courier_latitude'] as num?)?.toDouble(),
      courierLongitude: (json['courier_longitude'] as num?)?.toDouble(),
      enterpriseId: json['enterprise_id'] as int?,
      enterpriseName: json['enterprise_name']?.toString(),
      itemsTotal: (json['items_total'] as num?)?.toDouble(),
      cancelRequested: json['cancel_requested'] == true,
      source: (json['source'] ?? 'online').toString(),
      orderType: (json['order_type'] ?? 'delivery').toString(),
      customerPhone: json['customer_phone']?.toString(),
    );
  }
}
