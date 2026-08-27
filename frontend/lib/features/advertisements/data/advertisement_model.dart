class Advertisement {
  const Advertisement({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.durationDays,
    required this.feeAmount,
    required this.viewCount,
    this.userName,
    this.category,
    this.contactPhone,
    this.imageUrl,
    this.rejectionReason,
    this.createdAt,
    this.approvedAt,
    this.startsAt,
    this.expiresAt,
  });

  final int id;
  final int userId;
  final String? userName;
  final String title;
  final String description;
  final String? category;
  final String? contactPhone;
  final String? imageUrl;
  final String status;
  final int durationDays;
  final double feeAmount;
  final int viewCount;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      userName: json['user_name'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String?,
      contactPhone: json['contact_phone'] as String?,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      durationDays: ((json['duration_days'] as num?) ?? 7).toInt(),
      feeAmount: ((json['fee_amount'] as num?) ?? 0).toDouble(),
      viewCount: ((json['view_count'] as num?) ?? 0).toInt(),
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: _parseDate(json['created_at']),
      approvedAt: _parseDate(json['approved_at']),
      startsAt: _parseDate(json['starts_at']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Advertisement copyWith({int? viewCount}) {
    return Advertisement(
      id: id,
      userId: userId,
      userName: userName,
      title: title,
      description: description,
      category: category,
      contactPhone: contactPhone,
      imageUrl: imageUrl,
      status: status,
      durationDays: durationDays,
      feeAmount: feeAmount,
      viewCount: viewCount ?? this.viewCount,
      rejectionReason: rejectionReason,
      createdAt: createdAt,
      approvedAt: approvedAt,
      startsAt: startsAt,
      expiresAt: expiresAt,
    );
  }
}

class AdvertisementSettings {
  const AdvertisementSettings({
    required this.price,
    required this.defaultDurationDays,
    required this.currentBalance,
  });

  final double price;
  final int defaultDurationDays;
  final double currentBalance;

  factory AdvertisementSettings.fromJson(Map<String, dynamic> json) {
    return AdvertisementSettings(
      price: ((json['price'] as num?) ?? 0).toDouble(),
      defaultDurationDays: ((json['default_duration_days'] as num?) ?? 7)
          .toInt(),
      currentBalance: ((json['current_balance'] as num?) ?? 0).toDouble(),
    );
  }
}
