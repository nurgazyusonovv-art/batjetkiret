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

  // Prevent concurrent navigation calls (double-tap, FCM + polling race)
  static bool _isNavigating = false;

  // If a tap arrived before auth was ready, queue it here
  static int? _pendingChatId;

  static void setAuth(String token, int userId) {
    _token = token;
    _userId = userId;

    // Flush any notification tap that arrived before login completed
    final pending = _pendingChatId;
    if (pending != null) {
      _pendingChatId = null;
      openChatById(pending);
    }
  }

  static void clear() {
    _token = null;
    _userId = null;
    _isNavigating = false;
    _pendingChatId = null;
  }

  static Future<void> openChatById(int chatId) async {
    // If not logged in yet, queue and wait for setAuth
    if (_token == null || _userId == null) {
      _pendingChatId = chatId;
      return;
    }

    // Prevent double-tap / concurrent navigation
    if (_isNavigating) return;
    _isNavigating = true;

    final key = navigatorKey;
    final token = _token!;
    final userId = _userId!;

    try {
      // Use navigatorKey.currentState — safe after async gaps (unlike BuildContext)
      final navState = key?.currentState;
      if (navState == null) return;

      final ctx = await OrderApi()
          .getChatContextByChatId(token: token, chatId: chatId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Чат жүктөөдө убакыт аяктады'),
          );

      // Re-check navigator is still alive after the await
      final nav = key?.currentState;
      if (nav == null) return;

      if (ctx.type == 'ORDER' && ctx.orderId != null) {
        nav.push(MaterialPageRoute(
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
        nav.push(MaterialPageRoute(
          builder: (_) => SupportChatPage(
            token: token,
            chatId: ctx.chatId,
            title: ctx.counterpartyName ?? 'Колдоо кызматы',
            myUserId: userId,
          ),
        ));
      }
    } catch (_) {
      // Silently ignore — user can open the chat manually
    } finally {
      _isNavigating = false;
    }
  }
}
