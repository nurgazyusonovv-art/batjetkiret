class ChatContext {
  final int chatId;
  final String type;
  final int? orderId;
  final int? counterpartyId;
  final String? counterpartyName;

  ChatContext({
    required this.chatId,
    required this.type,
    required this.orderId,
    required this.counterpartyId,
    required this.counterpartyName,
  });

  factory ChatContext.fromJson(Map<String, dynamic> json) {
    return ChatContext(
      chatId: (json['chat_id'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? '').toString(),
      orderId: (json['order_id'] as num?)?.toInt(),
      counterpartyId: (json['counterparty_id'] as num?)?.toInt(),
      counterpartyName: json['counterparty_name']?.toString(),
    );
  }
}
