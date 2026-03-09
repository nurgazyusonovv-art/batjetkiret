class ChatMessage {
  final int id;
  final int senderId;
  final String text;
  final String createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      text: (json['text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      isRead: json['is_read'] == true,
    );
  }

  ChatMessage copyWith({
    int? id,
    int? senderId,
    String? text,
    String? createdAt,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
