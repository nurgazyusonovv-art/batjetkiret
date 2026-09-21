class NotificationItem {
  final int id;
  final String title;
  final String message;
  final int? chatId;
  final int? orderId;
  // Campaign notifications carry a picture and the shop they advertise.
  final String? imageUrl;
  final int? enterpriseId;
  final String? enterpriseCategory;
  final String? type;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.chatId,
    required this.orderId,
    this.imageUrl,
    this.enterpriseId,
    this.enterpriseCategory,
    this.type,
    required this.isRead,
    required this.createdAt,
  });

  bool get isPromo => (imageUrl ?? '').isNotEmpty || type == 'promo';

  NotificationItem copyWithRead() => NotificationItem(
        id: id,
        title: title,
        message: message,
        chatId: chatId,
        orderId: orderId,
        imageUrl: imageUrl,
        enterpriseId: enterpriseId,
        enterpriseCategory: enterpriseCategory,
        type: type,
        isRead: true,
        createdAt: createdAt,
      );

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      chatId: (json['chat_id'] as num?)?.toInt(),
      orderId: (json['order_id'] as num?)?.toInt(),
      imageUrl: (json['image_url'] as String?)?.trim().isNotEmpty == true
          ? (json['image_url'] as String).trim()
          : null,
      enterpriseId: (json['enterprise_id'] as num?)?.toInt(),
      enterpriseCategory: json['enterprise_category'] as String?,
      type: json['type'] as String?,
      isRead: json['is_read'] == true,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
