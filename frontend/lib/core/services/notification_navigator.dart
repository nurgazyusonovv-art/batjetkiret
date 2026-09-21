import 'package:flutter/material.dart';
import '../../features/home/data/category_model.dart' as models;
import '../../features/home/presentation/home_page.dart';
import '../../features/orders/data/order_api.dart';
import '../../features/orders/presentation/order_chat_page.dart';
import '../../features/profile/presentation/support_chat_page.dart';

/// Stores auth context and opens the correct screen
/// when a notification is tapped (from FCM or local notification).
class NotificationNavigator {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? _token;
  static int? _userId;

  // Prevent concurrent navigation calls
  static bool _isNavigating = false;

  // Queue taps that arrive before auth is ready
  static int? _pendingChatId;
  static int? _pendingOrderId;
  static int? _pendingEnterpriseId;
  static String? _pendingEnterpriseCategory;

  static void setAuth(String token, int userId) {
    _token = token;
    _userId = userId;

    final pendingChat = _pendingChatId;
    final pendingOrder = _pendingOrderId;
    final pendingEnterprise = _pendingEnterpriseId;
    final pendingCategory = _pendingEnterpriseCategory;
    _pendingChatId = null;
    _pendingOrderId = null;
    _pendingEnterpriseId = null;
    _pendingEnterpriseCategory = null;

    if (pendingEnterprise != null) {
      openEnterpriseById(pendingEnterprise, pendingCategory);
    } else if (pendingOrder != null) {
      openOrderById(pendingOrder);
    } else if (pendingChat != null) {
      openChatById(pendingChat);
    }
  }

  static void clear() {
    _token = null;
    _userId = null;
    _isNavigating = false;
    _pendingChatId = null;
    _pendingOrderId = null;
    _pendingEnterpriseId = null;
    _pendingEnterpriseCategory = null;
  }

  /// Opens the shop advertised by a campaign notification.
  static Future<void> openEnterpriseById(
    int enterpriseId,
    String? categoryId,
  ) async {
    if (_token == null || _userId == null) {
      _pendingEnterpriseId = enterpriseId;
      _pendingEnterpriseCategory = categoryId;
      return;
    }

    if (_isNavigating) return;
    _isNavigating = true;

    try {
      final nav = navigatorKey?.currentState;
      if (nav == null) return;

      final category = models.categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => models.categories.first,
      );
      nav.push(
        MaterialPageRoute(
          builder: (_) => OrderCreatePage(
            token: _token!,
            selectedCategory: category,
            initialEnterpriseId: enterpriseId,
          ),
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  static Future<void> openChatById(int chatId) async {
    if (_token == null || _userId == null) {
      _pendingChatId = chatId;
      return;
    }

    if (_isNavigating) return;
    _isNavigating = true;

    final key = navigatorKey;
    final token = _token!;
    final userId = _userId!;

    try {
      final navState = key?.currentState;
      if (navState == null) return;

      final ctx = await OrderApi()
          .getChatContextByChatId(token: token, chatId: chatId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Чат жүктөөдө убакыт аяктады'),
          );

      final nav = key?.currentState;
      if (nav == null) return;

      if (ctx.type == 'ORDER' && ctx.orderId != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => OrderChatPage(
              token: token,
              orderId: ctx.orderId!,
              counterpartyName: ctx.counterpartyName ?? 'Чат',
              counterpartyId: ctx.counterpartyId,
            ),
          ),
        );
        return;
      }

      if (ctx.type == 'SUPPORT') {
        nav.push(
          MaterialPageRoute(
            builder: (_) => SupportChatPage(
              token: token,
              chatId: ctx.chatId,
              title: ctx.counterpartyName ?? 'Колдоо кызматы',
              myUserId: userId,
            ),
          ),
        );
      }
    } catch (_) {
      // Silently ignore — user can open the chat manually
    } finally {
      _isNavigating = false;
    }
  }

  /// Navigate to the order chat when user taps an order-status notification.
  static Future<void> openOrderById(int orderId) async {
    if (_token == null || _userId == null) {
      _pendingOrderId = orderId;
      return;
    }

    if (_isNavigating) return;
    _isNavigating = true;

    final key = navigatorKey;
    final token = _token!;

    try {
      final navState = key?.currentState;
      if (navState == null) return;

      // Find the chat for this order and open it
      final ctx = await OrderApi()
          .getChatContextByOrderId(token: token, orderId: orderId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('timeout'),
          );

      final nav = key?.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => OrderChatPage(
            token: token,
            orderId: orderId,
            counterpartyName: ctx.counterpartyName ?? 'Заказ #$orderId',
            counterpartyId: ctx.counterpartyId,
          ),
        ),
      );
    } catch (_) {
      // If chat fetch fails, silently ignore — user can navigate manually
    } finally {
      _isNavigating = false;
    }
  }

  static void _openOrderWithRetry(int orderId, {int attempt = 0}) {
    const delays = [500, 1000, 2000, 3000];
    final ms = attempt < delays.length ? delays[attempt] : 0;
    if (ms == 0) return;

    Future.delayed(Duration(milliseconds: ms), () {
      if (navigatorKey?.currentState != null) {
        openOrderById(orderId);
      } else {
        _openOrderWithRetry(orderId, attempt: attempt + 1);
      }
    });
  }

  static void _openChatWithRetry(int chatId, {int attempt = 0}) {
    const delays = [500, 1000, 2000, 3000];
    final ms = attempt < delays.length ? delays[attempt] : 0;
    if (ms == 0) return;

    Future.delayed(Duration(milliseconds: ms), () {
      if (navigatorKey?.currentState != null) {
        openChatById(chatId);
      } else {
        _openChatWithRetry(chatId, attempt: attempt + 1);
      }
    });
  }

  static void _openEnterpriseWithRetry(
    int enterpriseId,
    String? categoryId, {
    int attempt = 0,
  }) {
    const delays = [500, 1000, 2000, 3000];
    final ms = attempt < delays.length ? delays[attempt] : 0;
    if (ms == 0) return;

    Future.delayed(Duration(milliseconds: ms), () {
      if (navigatorKey?.currentState != null) {
        openEnterpriseById(enterpriseId, categoryId);
      } else {
        _openEnterpriseWithRetry(
          enterpriseId,
          categoryId,
          attempt: attempt + 1,
        );
      }
    });
  }

  // Expose retry helpers for FCM terminated-app launch
  static void openChatByIdWithRetry(int chatId) => _openChatWithRetry(chatId);
  static void openOrderByIdWithRetry(int orderId) =>
      _openOrderWithRetry(orderId);
  static void openEnterpriseByIdWithRetry(
    int enterpriseId,
    String? categoryId,
  ) => _openEnterpriseWithRetry(enterpriseId, categoryId);
}
