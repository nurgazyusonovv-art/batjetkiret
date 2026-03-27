import 'package:flutter/material.dart';
import '../../features/orders/data/order_api.dart';
import '../../features/orders/presentation/order_chat_page.dart';
import '../../features/profile/presentation/support_chat_page.dart';

/// Stores auth context and opens the correct chat screen
/// when a notification is tapped (from FCM or local notification).
class NotificationNavigator {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? _token;
  static int? _userId;

  static void setAuth(String token, int userId) {
    _token = token;
    _userId = userId;
  }

  static void clear() {
    _token = null;
    _userId = null;
  }

  static Future<void> openChatById(int chatId) async {
    final key = navigatorKey;
    final token = _token;
    final userId = _userId;
    if (key == null || token == null || userId == null) return;

    final context = key.currentContext;
    if (context == null) return;

    try {
      final ctx = await OrderApi().getChatContextByChatId(
        token: token,
        chatId: chatId,
      );

      if (!context.mounted) return;

      if (ctx.type == 'ORDER' && ctx.orderId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderChatPage(
            token: token,
            orderId: ctx.orderId!,
            counterpartyName: ctx.counterpartyName ?? 'Чат',
            counterpartyId: ctx.counterpartyId,
          ),
        ));
        return;
      }

      if (ctx.type == 'SUPPORT') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SupportChatPage(
            token: token,
            chatId: ctx.chatId,
            title: ctx.counterpartyName ?? 'Колдоо кызматы',
            myUserId: userId,
          ),
        ));
      }
    } catch (_) {}
  }
}
