class OrderStatusAuditEntry {
  final int? actorUserId;
  final String? fromStatus;
  final String toStatus;
  final String at;

  OrderStatusAuditEntry({
    required this.actorUserId,
    required this.fromStatus,
    required this.toStatus,
    required this.at,
  });

  factory OrderStatusAuditEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusAuditEntry(
      actorUserId: (json['actor_user_id'] as num?)?.toInt(),
      fromStatus: json['from_status']?.toString(),
      toStatus: (json['to_status'] ?? '').toString(),
      at: (json['at'] ?? '').toString(),
    );
  }
}
