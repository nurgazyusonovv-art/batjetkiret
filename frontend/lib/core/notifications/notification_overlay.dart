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
  Timer? _autoDismissTimer;
  late final StreamSubscription<Map<String, dynamic>> subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = NotificationsService.notificationStream.listen(
      _showNotification,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription.cancel();
    _autoDismissTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showNotification(Map<String, dynamic> notification) {
    if (_isVisible) return;
    _isVisible = true;

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedBannerEntry(
        notification: notification,
        onDismiss: _dismissNotification,
      ),
    );

    overlayState.insert(_overlayEntry!);

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 5), _dismissNotification);
  }

  void _dismissNotification() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ──────────────────────────────────────────────
// Animated wrapper: slide-in from top + swipe-to-dismiss
// ──────────────────────────────────────────────
class _AnimatedBannerEntry extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;

  const _AnimatedBannerEntry({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_AnimatedBannerEntry> createState() => _AnimatedBannerEntryState();
}

class _AnimatedBannerEntryState extends State<_AnimatedBannerEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideY;   // 0 = hidden above, 1 = final pos
  late final Animation<double> _opacity;

  // Swipe tracking
  double _dragOffset = 0;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideY = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut({double velocityY = 0}) async {
    if (_isDismissed) return;
    _isDismissed = true;
    await _controller.reverse();
    widget.onDismiss();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Allow dragging up and sideways; resist dragging down
    final dy = d.delta.dy;
    final dx = d.delta.dx;
    setState(() {
      if (dy < 0) {
        _dragOffset += dy;            // swipe up — full speed
      } else {
        _dragOffset += dy * 0.2;      // swipe down — strongly resist
      }
      _dragOffset += dx.abs() * 0.05; // sideways also counts slightly
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond;
    // Dismiss if dragged up >60px or flung upward fast
    if (_dragOffset < -60 || velocity.dy < -400) {
      _animateOut(velocityY: velocity.dy);
    } else {
      // Snap back
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slideOffset = (1 - _slideY.value) * -80;
        final totalOffset = slideOffset + _dragOffset;
        final swipeFraction = (_dragOffset.abs() / 80).clamp(0.0, 1.0);

        return Positioned(
          top: topPadding + 16 + totalOffset,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: (_opacity.value * (1 - swipeFraction * 0.6)).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: _NotificationBanner(
          notification: widget.notification,
          onDismiss: () => _animateOut(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Banner UI (unchanged look)
// ──────────────────────────────────────────────
class _NotificationBanner extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final notificationType = notification['type'] as String? ?? 'info';

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
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Colored left bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: accentColor),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
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
