import 'dart:async';
import 'package:flutter/material.dart';
import 'notifications_service.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  bool _isVisible = false;
  late final StreamSubscription<Map<String, dynamic>> subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Слушаем уведомления из сервиса
    subscription = NotificationsService.notificationStream.listen((
      notification,
    ) {
      _showNotification(notification);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showNotification(Map<String, dynamic> notification) {
    if (_isVisible) return;

    _isVisible = true;

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Positioned(
            top: MediaQuery.of(context).padding.top + 16 - ((1 - value) * 10),
            left: 16,
            right: 16,
            child: Opacity(opacity: value, child: child),
          );
        },
        child: _NotificationBanner(
          notification: notification,
          onDismiss: _dismissNotification,
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);

    // Автоматическое скрытие через 5 секунд
    Future.delayed(const Duration(seconds: 5), _dismissNotification);
  }

  void _dismissNotification() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NotificationBanner extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    Key? key,
    required this.notification,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final notificationType = notification['type'] as String? ?? 'info';

    // Выбираем цвет в зависимости от типа уведомления
    Color accentColor = Colors.blue;
    IconData iconData = Icons.notifications;

    switch (notificationType) {
      case 'error':
        accentColor = Colors.red;
        iconData = Icons.error;
        break;
      case 'success':
      case 'topup_approved':
      case 'rating_received':
        accentColor = Colors.green;
        iconData = Icons.check_circle;
        break;
      case 'warning':
        accentColor = Colors.orange;
        iconData = Icons.warning;
        break;
      default:
        accentColor = Colors.blue;
        iconData = Icons.notifications;
    }

    return Material(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Боковая полоса с цветом
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: accentColor),
              ),
              // Основной контент
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Иконка
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Текст
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Кнопка закрытия
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
