import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/data/order_api.dart';
import '../../orders/presentation/order_chat_page.dart';
import 'support_chat_page.dart';
import '../data/notification_item.dart';
import '../data/user_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.token, required this.userId});

  final String token;
  final int userId;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final UserApi _userApi = UserApi();
  final OrderApi _orderApi = OrderApi();

  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _error;
  List<NotificationItem> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _userApi.getNotifications(widget.token);
      if (!mounted) return;
      setState(() => _notifications = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await _userApi.markNotificationRead(widget.token, item.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => n.id == item.id ? n.copyWithRead() : n).toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread || _isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      await _userApi.markAllNotificationsRead(widget.token);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => n.copyWithRead()).toList();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _deleteNotification(NotificationItem item) async {
    // Optimistic: remove from list immediately
    setState(() {
      _notifications = _notifications.where((n) => n.id != item.id).toList();
    });
    try {
      await _userApi.deleteNotification(widget.token, item.id);
    } catch (_) {
      // Restore on failure
      if (!mounted) return;
      setState(() {
        final list = List<NotificationItem>.from(_notifications);
        list.add(item);
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _notifications = list;
      });
    }
  }

  Future<void> _openChatFromNotification(NotificationItem item) async {
    final chatId = item.chatId;
    if (chatId == null) return;
    try {
      final contextData = await _orderApi.getChatContextByChatId(
        token: widget.token,
        chatId: chatId,
      );
      if (!mounted) return;

      if (contextData.type == 'ORDER' && contextData.orderId != null) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderChatPage(
            token: widget.token,
            orderId: contextData.orderId!,
            counterpartyName: contextData.counterpartyName ?? 'Чат',
            counterpartyId: contextData.counterpartyId,
          ),
        ));
        return;
      }

      if (contextData.type == 'SUPPORT') {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SupportChatPage(
            token: widget.token,
            chatId: contextData.chatId,
            title: contextData.counterpartyName ?? 'Колдоо кызматы',
            myUserId: widget.userId,
          ),
        ));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бул билдирмеден чатка өтүү мүмкүн эмес')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чатты ачууда ката кетти')),
      );
    }
  }

  Future<void> _handleTap(NotificationItem item) async {
    await _markRead(item);
    await _openChatFromNotification(item);
  }

  String _formatDate(String raw) {
    final utc = raw.endsWith('Z') ? raw : '${raw}Z';
    final date = DateTime.tryParse(utc);
    if (date == null) return raw;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Билдирмелер',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _isMarkingAll ? null : _markAllRead,
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, size: 18),
              label: const Text('Баарын окудум', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.accent5)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Кайра аракет кылуу'),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 48, color: AppColors.textSecondary),
                                SizedBox(height: 12),
                                Text(
                                  'Билдирмелер жок',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          return _NotificationCard(
                            key: ValueKey(item.id),
                            item: item,
                            onTap: () => _handleTap(item),
                            onDelete: () => _deleteNotification(item),
                            formatDate: _formatDate,
                          );
                        },
                      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Swipe-to-delete card
// ─────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.formatDate,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(String) formatDate;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    final canOpenChat = item.chatId != null && item.chatId! > 0;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Өчүрүү'),
            content: const Text('Бул билдирмени өчүрөсүзбү?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Жок'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Өчүрүү'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: canOpenChat ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isUnread
                ? AppColors.primary.withAlpha(14)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withAlpha(100)
                  : AppColors.border,
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon — filled for unread, outlined for read
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? AppColors.primary.withAlpha(30)
                        : AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isUnread
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    color: isUnread
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // Unread dot
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnread
                              ? AppColors.textPrimary.withAlpha(200)
                              : AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 11,
                            color: AppColors.textSecondary.withAlpha(160),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatDate(item.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withAlpha(160),
                            ),
                          ),
                          if (canOpenChat) ...[
                            const Spacer(),
                            Text(
                              'Чат ачуу →',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary.withAlpha(180),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
