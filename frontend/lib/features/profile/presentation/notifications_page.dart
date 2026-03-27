import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/data/order_api.dart';
import '../../orders/presentation/order_chat_page.dart';
import 'support_chat_page.dart';
import '../data/notification_item.dart';
import '../data/user_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.token});

  final String token;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final UserApi _userApi = UserApi();
  final OrderApi _orderApi = OrderApi();

  bool _isLoading = true;
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

      setState(() {
        _notifications = items;
      });

      // Mark all as read silently after displaying
      await _userApi.markAllNotificationsRead(widget.token);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationItem(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  chatId: n.chatId,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;

    try {
      await _userApi.markNotificationRead(widget.token, item.id);
      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id != item.id) return n;
          return NotificationItem(
            id: n.id,
            title: n.title,
            message: n.message,
            chatId: n.chatId,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
      });
    } catch (_) {
      // Do not block user interaction if marking read fails.
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderChatPage(
              token: widget.token,
              orderId: contextData.orderId!,
              counterpartyName: contextData.counterpartyName ?? 'Чат',
              counterpartyId: contextData.counterpartyId,
            ),
          ),
        );
        return;
      }

      if (contextData.type == 'SUPPORT') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupportChatPage(
              token: widget.token,
              chatId: contextData.chatId,
              title: contextData.counterpartyName ?? 'Колдоо кызматы',
              counterpartyId: contextData.counterpartyId,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бул билдирмеден чатка өтүү мүмкүн эмес')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Чатты ачууда ката кетти')));
    }
  }

  Future<void> _handleNotificationTap(NotificationItem item) async {
    await _markRead(item);
    await _openChatFromNotification(item);
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Widget _buildItem(NotificationItem item) {
    final isUnread = !item.isRead;
    final canOpenChat = item.chatId != null && item.chatId! > 0;

    return InkWell(
      onTap: canOpenChat ? () => _handleNotificationTap(item) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primary.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withAlpha(120)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatDate(item.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Билдирмелер',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
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
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.accent5),
                  ),
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
                    child: Text(
                      'Билдирмелер жок',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  return _buildItem(item);
                },
              ),
      ),
    );
  }
}
