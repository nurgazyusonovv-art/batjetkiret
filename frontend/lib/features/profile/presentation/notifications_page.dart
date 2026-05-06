import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/data/order_api.dart';
import '../../orders/presentation/order_chat_page.dart';
import 'support_chat_page.dart';
import '../data/notification_item.dart';
import '../data/user_api.dart';

// ── Category enum ─────────────────────────────────────────────────────────────

enum _NotifCategory { all, orders, chat, wallet, system }

extension _NotifCategoryX on _NotifCategory {
  String get label {
    switch (this) {
      case _NotifCategory.all:     return 'Баары';
      case _NotifCategory.orders:  return 'Заказдар';
      case _NotifCategory.chat:    return 'Чат';
      case _NotifCategory.wallet:  return 'Капчык';
      case _NotifCategory.system:  return 'Система';
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifCategory.all:    return Icons.notifications_outlined;
      case _NotifCategory.orders: return Icons.receipt_long_outlined;
      case _NotifCategory.chat:   return Icons.chat_bubble_outline;
      case _NotifCategory.wallet: return Icons.account_balance_wallet_outlined;
      case _NotifCategory.system: return Icons.info_outline;
    }
  }

  Color get color {
    switch (this) {
      case _NotifCategory.all:    return AppColors.primary;
      case _NotifCategory.orders: return const Color(0xFF0284C7);
      case _NotifCategory.chat:   return const Color(0xFF059669);
      case _NotifCategory.wallet: return const Color(0xFF7C3AED);
      case _NotifCategory.system: return const Color(0xFF92400E);
    }
  }
}

_NotifCategory _categoryOf(NotificationItem n) {
  final t = n.title;
  final tl = t.toLowerCase();
  if (t.contains('💳') || tl.contains('топап') || tl.contains('капчык')) {
    return _NotifCategory.wallet;
  }
  if (t.contains('💬') || tl.contains('колдоо')) {
    return _NotifCategory.chat;
  }
  if (t.contains('🛎') || tl.contains('заказ') || tl.contains('чыгаруу')) {
    return _NotifCategory.orders;
  }
  if (n.chatId != null) return _NotifCategory.chat;
  return _NotifCategory.system;
}

// ── Page ─────────────────────────────────────────────────────────────────────

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
  _NotifCategory _selectedCategory = _NotifCategory.all;

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
        _notifications = _notifications
            .map((n) => n.id == item.id ? n.copyWithRead() : n)
            .toList();
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
    setState(() {
      _notifications = _notifications.where((n) => n.id != item.id).toList();
    });
    try {
      await _userApi.deleteNotification(widget.token, item.id);
    } catch (_) {
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
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    if (isToday) return 'Бүгүн  $hour:$min';
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month  $hour:$min';
  }

  // ── Filtered list ───────────────────────────────────────────────────────────

  List<NotificationItem> get _filtered {
    if (_selectedCategory == _NotifCategory.all) return _notifications;
    return _notifications
        .where((n) => _categoryOf(n) == _selectedCategory)
        .toList();
  }

  /// Categories that have at least one notification
  List<_NotifCategory> get _activeCategories {
    final cats = <_NotifCategory>{};
    for (final n in _notifications) {
      cats.add(_categoryOf(n));
    }
    return [
      _NotifCategory.all,
      ..._NotifCategory.values
          .where((c) => c != _NotifCategory.all && cats.contains(c)),
    ];
  }

  int _unreadIn(_NotifCategory cat) {
    if (cat == _NotifCategory.all) {
      return _notifications.where((n) => !n.isRead).length;
    }
    return _notifications
        .where((n) => _categoryOf(n) == cat && !n.isRead)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final totalUnread = _notifications.where((n) => !n.isRead).length;

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
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalUnread',
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
                      Text(_error!,
                          style: const TextStyle(color: AppColors.accent5)),
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
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // ── Filter chips ────────────────────────────────
                          _buildFilterChips(),

                          // ── Mark-all button ─────────────────────────────
                          if (totalUnread > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _isMarkingAll ? null : _markAllRead,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: _isMarkingAll
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.done_all, size: 18),
                                  label: Text(
                                    'Баарын окулду деп белги коюу ($totalUnread)',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),

                          // ── Notification list ───────────────────────────
                          Expanded(child: _buildList()),
                        ],
                      ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        children: _activeCategories.map((cat) {
          final selected = _selectedCategory == cat;
          final unread = _unreadIn(cat);
          final color = cat.color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 15,
                      color: selected ? Colors.white : color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.3)
                              : color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unread',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_selectedCategory.icon,
                size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              '"${_selectedCategory.label}" категориясында билдирме жок',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group into unread → read sections
    final unread = items.where((n) => !n.isRead).toList();
    final read = items.where((n) => n.isRead).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        if (unread.isNotEmpty) ...[
          _sectionHeader('Окулбагандар', unread.length),
          ...unread.map((item) => _NotificationCard(
                key: ValueKey(item.id),
                item: item,
                category: _categoryOf(item),
                onTap: () => _handleTap(item),
                onDelete: () => _deleteNotification(item),
                formatDate: _formatDate,
              )),
        ],
        if (read.isNotEmpty) ...[
          _sectionHeader('Окулгандар', null),
          ...read.map((item) => _NotificationCard(
                key: ValueKey(item.id),
                item: item,
                category: _categoryOf(item),
                onTap: () => _handleTap(item),
                onDelete: () => _deleteNotification(item),
                formatDate: _formatDate,
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, int? count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.category,
    required this.onTap,
    required this.onDelete,
    required this.formatDate,
  });

  final NotificationItem item;
  final _NotifCategory category;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(String) formatDate;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    final canOpenChat = item.chatId != null && item.chatId! > 0;
    final catColor = category.color;

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
        ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: canOpenChat ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isUnread ? catColor.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? catColor.withValues(alpha: 0.35)
                  : AppColors.border,
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? catColor.withValues(alpha: 0.15)
                        : catColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    category.icon,
                    color: isUnread ? catColor : catColor.withValues(alpha: 0.6),
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
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: catColor,
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
                              ? AppColors.textPrimary.withValues(alpha: 0.78)
                              : AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(category.icon,
                                    size: 10, color: catColor),
                                const SizedBox(width: 3),
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatDate(item.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          if (canOpenChat) ...[
                            const Spacer(),
                            Text(
                              'Чат ачуу →',
                              style: TextStyle(
                                fontSize: 11,
                                color: catColor.withValues(alpha: 0.8),
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
