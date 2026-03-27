// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../data/order_api.dart';
import '../data/order_model.dart';
import 'cubit/orders_cubit.dart';
import 'cubit/orders_state.dart';
import 'order_history_page.dart';
import 'order_detail_page.dart';
import 'widgets/advanced_filter_dialog.dart';

enum OrderFilterStatus { all, pending, active, completed }

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key, required this.token});

  final String token;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  OrderFilterStatus _filterStatus = OrderFilterStatus.all;
  AdvancedFilterOptions? _advancedFilterOptions;
  final OrderApi _orderApi = OrderApi();
  final Map<int, int> _unreadCounts = {};
  String _ordersUnreadSignature = '';
  WebSocketChannel? _ordersSocket;
  StreamSubscription<dynamic>? _ordersSocketSubscription;
  Timer? _ordersSocketReconnectTimer;
  bool _isOrdersSocketConnected = false;
  int _ordersSocketRetryCount = 0;
  static const int _maxSocketRetries = 10;
  static const int _baseRetrySeconds = 2;

  @override
  void initState() {
    super.initState();
    _connectOrdersSocket();
  }

  @override
  void dispose() {
    _ordersSocketReconnectTimer?.cancel();
    _ordersSocketSubscription?.cancel();
    _ordersSocket?.sink.close();
    super.dispose();
  }

  Future<void> _connectOrdersSocket() async {
    final token = widget.token.trim();
    if (token.isEmpty || !mounted) return;

    _ordersSocketReconnectTimer?.cancel();
    await _ordersSocketSubscription?.cancel();
    await _ordersSocket?.sink.close();

    try {
      final uri = _orderApi.buildMyOrdersWebSocketUri(token: token);
      final channel = WebSocketChannel.connect(uri);
      _ordersSocket = channel;

      _ordersSocketSubscription = channel.stream.listen(
        _handleOrdersSocketEvent,
        onError: (_) => _onOrdersSocketClosed(),
        onDone: _onOrdersSocketClosed,
        cancelOnError: true,
      );

      if (!mounted) return;
      setState(() {
        _isOrdersSocketConnected = true;
        _ordersSocketRetryCount = 0;
      });
    } catch (_) {
      _onOrdersSocketClosed();
    }
  }

  void _onOrdersSocketClosed() {
    if (!mounted) return;

    setState(() {
      _isOrdersSocketConnected = false;
    });

    if (_ordersSocketRetryCount >= _maxSocketRetries) return;

    // Exponential backoff: 2s, 4s, 8s, … capped at 64s
    final delaySec = _baseRetrySeconds << _ordersSocketRetryCount.clamp(0, 5);
    _ordersSocketRetryCount++;

    _ordersSocketReconnectTimer?.cancel();
    _ordersSocketReconnectTimer = Timer(Duration(seconds: delaySec), () {
      _connectOrdersSocket();
    });
  }

  void _handleOrdersSocketEvent(dynamic raw) {
    if (!mounted) return;

    Map<String, dynamic>? payload;
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } else if (raw is Map) {
        payload = raw.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return;
    }

    if (payload == null || payload['event'] != 'orders_snapshot') {
      return;
    }

    final ordersPayload = payload['orders'];
    if (ordersPayload is! List) return;

    final unreadByOrderId = <int, int>{};
    final statusByOrderId = <int, String>{};

    for (final item in ordersPayload) {
      if (item is! Map) continue;
      final normalized = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final orderId = (normalized['id'] as num?)?.toInt();
      if (orderId == null) continue;

      unreadByOrderId[orderId] =
          (normalized['unread_count'] as num?)?.toInt() ?? 0;

      final rawStatus = normalized['status']?.toString();
      if (rawStatus != null && rawStatus.isNotEmpty) {
        statusByOrderId[orderId] = _normalizeStatus(rawStatus);
      }
    }

    setState(() {
      _unreadCounts
        ..clear()
        ..addEntries(unreadByOrderId.entries);
    });

    context.read<OrdersCubit>().applyRealtimeOrderStatuses(statusByOrderId);
  }

  Future<void> _syncUnreadCounts(
    List<Order> orders, {
    bool force = false,
  }) async {
    final token = widget.token.trim();
    if (token.isEmpty) return;

    final orderIds = orders.map((o) => o.id).toList()..sort();
    final signature = orderIds.join(',');
    if (!force && signature == _ordersUnreadSignature) return;

    _ordersUnreadSignature = signature;

    if (orderIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _unreadCounts.clear();
      });
      return;
    }

    final entries = await Future.wait(
      orderIds.map((orderId) async {
        final count = await _orderApi.getOrderUnreadChatCount(
          token: token,
          orderId: orderId,
        );
        return MapEntry(orderId, count);
      }),
    );

    if (!mounted) return;
    setState(() {
      _unreadCounts
        ..clear()
        ..addEntries(entries);
    });
  }

  Future<void> _refreshUnreadForOrder(int orderId) async {
    final token = widget.token.trim();
    if (token.isEmpty) return;

    final count = await _orderApi.getOrderUnreadChatCount(
      token: token,
      orderId: orderId,
    );

    if (!mounted) return;
    setState(() {
      _unreadCounts[orderId] = count;
    });
  }

  static String _normalizeStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'WAITING_COURIER': return 'pending';
      case 'ACCEPTED': return 'accepted';
      case 'READY': return 'ready';
      case 'IN_TRANSIT': return 'in_transit';
      case 'ON_THE_WAY': return 'in_transit';
      case 'PICKED_UP': return 'picked_up';
      case 'DELIVERED': return 'delivered';
      case 'COMPLETED': return 'completed';
      case 'CANCELLED': return 'cancelled';
      default: return raw.toLowerCase();
    }
  }

  static bool _isActiveStatus(String status) =>
      status == 'accepted' ||
      status == 'ready' ||
      status == 'in_transit' ||
      status == 'delivered' ||
      status == 'picked_up';

  List<Order> _filteredOrders(OrdersState state) {
    // Show all orders, but filter completed ones to today only
    var orders = state.orders.where((o) {
      if (o.status == 'completed' || o.status == 'cancelled') {
        return _isOrderFromToday(o);
      }
      return true; // always show active/pending orders regardless of date
    }).toList();

    // Apply advanced filters first
    if (_advancedFilterOptions != null &&
        _advancedFilterOptions!.hasActiveFilters) {
      orders = orders
          .where((order) => _advancedFilterOptions!.matchesOrder(order))
          .toList();
    }

    // Then apply status filters
    if (state.isCourier) {
      switch (_filterStatus) {
        case OrderFilterStatus.completed:
          return orders.where((o) => o.status == 'completed').toList();
        case OrderFilterStatus.active:
        default:
          return orders.where((o) => _isActiveStatus(o.status)).toList();
      }
    }

    if (_filterStatus == OrderFilterStatus.all) {
      return orders;
    }

    switch (_filterStatus) {
      case OrderFilterStatus.pending:
        return orders.where((o) => o.status == 'pending').toList();
      case OrderFilterStatus.active:
        return orders.where((o) => _isActiveStatus(o.status)).toList();
      case OrderFilterStatus.completed:
        return orders.where((o) => o.status == 'completed').toList();
      default:
        return orders;
    }
  }

  bool _isOrderFromToday(Order order) {
    final raw = order.createdAt;
    final parsed = DateTime.tryParse(raw.endsWith('Z') ? raw : '${raw}Z');
    if (parsed == null) return false;

    final local = parsed.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final ordersCubit = context.read<OrdersCubit>();
    return BlocConsumer<OrdersCubit, OrdersState>(
      listener: (context, state) {
        if (state.isCourier &&
            (_filterStatus == OrderFilterStatus.all ||
                _filterStatus == OrderFilterStatus.pending)) {
          setState(() {
            _filterStatus = OrderFilterStatus.active;
          });
        }
        if (!state.isCourier && _filterStatus == OrderFilterStatus.active) {
          setState(() {
            _filterStatus = OrderFilterStatus.all;
          });
        }

        if (!_isOrdersSocketConnected) {
          _syncUnreadCounts(state.orders);
        }
      },
      builder: (context, state) {
        final filteredOrders = _filteredOrders(state);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text(
              'Заказдарым',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              // Advanced Filter Icon
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Кошумча фильтр',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AdvancedFilterDialog(
                          initialOptions: _advancedFilterOptions,
                          onApply: (options) {
                            setState(() {
                              _advancedFilterOptions = options;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  if (_advancedFilterOptions?.hasActiveFilters ?? false)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.history, color: AppColors.textPrimary),
                tooltip: 'Тарых',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OrderHistoryPage(token: widget.token),
                    ),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => ordersCubit.loadOrders(widget.token),
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        AppButton.primary(
                          onPressed: () => ordersCubit.loadOrders(widget.token),
                          label: 'Кайра жүктөө',
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: state.isCourier
                            ? Row(
                                children: [
                                  _buildFilterButton(
                                    icon: Icons.local_shipping,
                                    label: 'Активдүү',
                                    isActive:
                                        _filterStatus ==
                                        OrderFilterStatus.active,
                                    activeColor: AppColors.accent3,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus =
                                            OrderFilterStatus.active;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterButton(
                                    icon: Icons.check_circle,
                                    label: 'Аякталган',
                                    isActive:
                                        _filterStatus ==
                                        OrderFilterStatus.completed,
                                    activeColor: AppColors.accent4,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus =
                                            OrderFilterStatus.completed;
                                      });
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildFilterButton(
                                    icon: Icons.dashboard,
                                    label: 'Бардыгы',
                                    isActive:
                                        _filterStatus == OrderFilterStatus.all,
                                    activeColor: AppColors.accent1,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus = OrderFilterStatus.all;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterButton(
                                    icon: Icons.schedule,
                                    label: 'Күтүүде',
                                    isActive:
                                        _filterStatus ==
                                        OrderFilterStatus.pending,
                                    activeColor: AppColors.accent2,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus =
                                            OrderFilterStatus.pending;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterButton(
                                    icon: Icons.local_shipping,
                                    label: 'Активдүү',
                                    isActive:
                                        _filterStatus ==
                                        OrderFilterStatus.active,
                                    activeColor: AppColors.accent3,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus =
                                            OrderFilterStatus.active;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildFilterButton(
                                    icon: Icons.check_circle,
                                    label: 'Аякталды',
                                    isActive:
                                        _filterStatus ==
                                        OrderFilterStatus.completed,
                                    activeColor: AppColors.accent4,
                                    onTap: () {
                                      setState(() {
                                        _filterStatus =
                                            OrderFilterStatus.completed;
                                      });
                                    },
                                  ),
                                ],
                              ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: filteredOrders.isEmpty
                              ? Center(
                                  key: const ValueKey('orders-empty'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        state.isCourier
                                            ? 'Курьер заказдары жок'
                                            : 'Заказдар жок',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  key: const ValueKey('orders-list'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  itemCount: filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: Duration(
                                        milliseconds: 220 + ((index % 6) * 45),
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, (1 - value) * 14),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildOrderCard(
                                        order,
                                        state.isCourier,
                                        _unreadCounts[order.id] ?? 0,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final iconColor = isActive ? activeColor : Colors.grey[350]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isActive ? activeColor.withAlpha(13) : Colors.white,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? Border.all(color: activeColor.withAlpha(128), width: 2)
                    : null,
              ),
              child: Center(child: Icon(icon, size: 32, color: iconColor)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? activeColor : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, bool isCourier, int unreadCount) {
    final isAwaitingConfirmation = !isCourier && order.status == 'delivered';
    final cardColor = _getCardColor(order.status);
    final accentColor = _getAccentColorForStatus(order.status);
    final effectiveBorderColor = isAwaitingConfirmation
        ? Colors.orange
        : cardColor.withAlpha(204);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              order: order,
              token: widget.token,
              isCourier: isCourier,
            ),
          ),
        );

        await _refreshUnreadForOrder(order.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardColor.withAlpha(38), cardColor.withAlpha(13)],
          ),
          border: Border.all(
            color: effectiveBorderColor,
            width: isAwaitingConfirmation ? 3 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge and ID header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (unreadCount > 0) ...[
                        _buildUnreadChatBadge(unreadCount),
                        const SizedBox(width: 8),
                      ],
                      _buildStatusBadgeModern(order.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Warning for user to provide verification code
              if (isAwaitingConfirmation)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Тастыктоо кодун курьерге бериңиз',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isAwaitingConfirmation) const SizedBox(height: 12),

              // Key benefits/features sections
              _buildOrderFeature(
                icon: Icons.shopping_bag_outlined,
                label: order.categoryName,
                value: _getCategoryIcon(order.category),
                color: accentColor,
              ),
              const SizedBox(height: 12),
              _buildOrderFeature(
                icon: Icons.route,
                label: 'Жеткирүү аралыгы',
                value: '${order.distance} км',
                color: accentColor,
              ),
              const SizedBox(height: 12),
              _buildOrderFeature(
                icon: Icons.location_on,
                label: 'Адрестер',
                value:
                    '${order.fromAddress.split(',').first} → ${order.toAddress.split(',').first}',
                color: accentColor,
              ),

              if (order.estimatedPrice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withAlpha(77)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Жеткирүү баасы',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${order.estimatedPrice?.round()} сом',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadChatBadge(int count) {
    final label = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent5,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOrderFeature({
    required IconData icon,
    required String label,
    required dynamic value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(38),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              value is IconData
                  ? Icon(value, size: 16, color: AppColors.primary)
                  : Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadgeModern(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppColors.accent2;
        textColor = Colors.white;
        label = 'Күтүүде';
        break;
      case 'accepted':
        bgColor = AppColors.accent3;
        textColor = Colors.white;
        label = 'Кабыл алынды';
        break;
      case 'ready':
        bgColor = const Color(0xFF059669);
        textColor = Colors.white;
        label = 'Даяр';
        break;
      case 'in_transit':
      case 'picked_up':
        bgColor = AppColors.accent3;
        textColor = Colors.white;
        label = 'Жол жүрүүдө';
        break;
      case 'completed':
      case 'delivered':
        bgColor = AppColors.accent4;
        textColor = Colors.white;
        label = 'Аякталды';
        break;
      case 'cancelled':
        bgColor = AppColors.accent5;
        textColor = Colors.white;
        label = 'Жокко чыгарылды';
        break;
      default:
        bgColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getCardColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.accent2;
      case 'accepted':
      case 'ready':
      case 'in_transit':
      case 'picked_up':
        return AppColors.accent3;
      case 'completed':
      case 'delivered':
        return AppColors.accent4;
      case 'cancelled':
        return AppColors.accent5;
      default:
        return AppColors.primary;
    }
  }

  Color _getAccentColorForStatus(String status) {
    switch (status) {
      case 'pending':
        return AppColors.accent2;
      case 'accepted':
      case 'ready':
      case 'in_transit':
      case 'picked_up':
        return AppColors.accent3;
      case 'completed':
      case 'delivered':
        return AppColors.accent4;
      case 'cancelled':
        return AppColors.accent5;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    const categoryIcons = {
      'food': Icons.restaurant,
      'groceries': Icons.shopping_cart,
      'pharmacy': Icons.local_pharmacy,
      'clothes': Icons.checkroom,
      'electronics': Icons.phone_android,
      'flowers': Icons.local_florist,
      'documents': Icons.description,
      'other': Icons.category,
    };
    return categoryIcons[category] ?? Icons.category;
  }

  String _formatDate(String dateString) {
    try {
      final utc = dateString.endsWith('Z') ? dateString : '${dateString}Z';
      final date = DateTime.parse(utc).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
