import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with WidgetsBindingObserver {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  static const _newStatuses = {'WAITING_COURIER', 'PREPARING', 'READY'};
  static const _closedStatuses = {'COMPLETED', 'DELIVERED', 'CANCELLED'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await ApiService.getAdminOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Заказдар жүктөлбөдү';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          toolbarHeight: 48,
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          title: const Text(
            'Заказдар',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _load,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            tabs: [
              Tab(text: 'Жаңы ${_newOrders.length}'),
              Tab(text: 'Активдүү ${_activeOrders.length}'),
              Tab(text: 'Жабылган ${_closedOrders.length}'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : TabBarView(
                children: [
                  _OrdersList(
                    orders: _newOrders,
                    emptyText: 'Жаңы заказдар жок',
                    showCourier: false,
                    onRefresh: _load,
                  ),
                  _OrdersList(
                    orders: _activeOrders,
                    emptyText: 'Активдүү заказдар жок',
                    showCourier: true,
                    onRefresh: _load,
                  ),
                  _OrdersList(
                    orders: _closedOrders,
                    emptyText: 'Жабылган заказдар жок',
                    showCourier: true,
                    onRefresh: _load,
                  ),
                ],
              ),
      ),
    );
  }

  List<dynamic> get _newOrders => _orders
      .where((o) => _newStatuses.contains((o as Map)['status'] as String?))
      .toList();

  List<dynamic> get _closedOrders => _orders
      .where((o) => _closedStatuses.contains((o as Map)['status'] as String?))
      .toList();

  List<dynamic> get _activeOrders => _orders.where((o) {
    final status = (o as Map)['status'] as String?;
    return !_newStatuses.contains(status) && !_closedStatuses.contains(status);
  }).toList();
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.emptyText,
    required this.showCourier,
    required this.onRefresh,
  });

  final List<dynamic> orders;
  final String emptyText;
  final bool showCourier;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: orders.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 180),
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    emptyText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) => _OrderCard(
                order: orders[i] as Map<String, dynamic>,
                showCourier: showCourier,
              ),
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemCount: orders.length,
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.showCourier});

  final Map<String, dynamic> order;
  final bool showCourier;

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] as String?) ?? '';
    final color = _statusColor(status);
    final price = (order['price'] as num?)?.toStringAsFixed(0) ?? '0';
    final createdAt = _formatDate(order['created_at']);
    final courier = [
      order['courier_name'],
      order['courier_phone'],
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' · ');
    final enterpriseName = _text(order['enterprise_name']).trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Заказ #${order['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusChip(label: _statusText(status), color: color),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.person_outline, text: _customerText()),
            if (enterpriseName.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.storefront_outlined,
                text: 'Ишкана: $enterpriseName',
              ),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.my_location_outlined,
              text: _text(order['from_address']),
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.flag_outlined,
              text: _text(order['to_address']),
            ),
            if (showCourier) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.delivery_dining,
                text: courier.isEmpty ? 'Курьер дайындала элек' : courier,
              ),
            ],
            if (_text(order['description']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _text(order['description']),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF4B5563), height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _Pill(icon: Icons.payments_outlined, text: '$price с'),
                const SizedBox(width: 8),
                _Pill(icon: Icons.category_outlined, text: _categoryText()),
                const Spacer(),
                Text(
                  createdAt,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _customerText() {
    final parts = [
      order['user_name'],
      order['user_phone'],
    ].whereType<String>().where((v) => v.trim().isNotEmpty).toList();
    return parts.isEmpty
        ? 'Колдонуучу #${order['user_id']}'
        : parts.join(' · ');
  }

  String _categoryText() {
    final category = _text(order['category']);
    final source = _text(order['source']);
    return source.isEmpty ? category : '$category/$source';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF374151), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4B5563)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFFDC2626))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Кайра жүктөө')),
        ],
      ),
    );
  }
}

String _text(Object? value) => (value ?? '').toString();

String _formatDate(Object? raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return '';
  final dt = DateTime.tryParse(value);
  if (dt == null) return value;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

String _statusText(String status) => switch (status) {
  'WAITING_COURIER' => 'Жаңы',
  'PREPARING' => 'Даярдалып жатат',
  'READY' => 'Даяр',
  'ACCEPTED' => 'Кабыл алынды',
  'ON_THE_WAY' => 'Жолдо',
  'DELIVERED' => 'Жеткирилди',
  'COMPLETED' => 'Аяктады',
  'CANCELLED' => 'Жокко чыгарылды',
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'WAITING_COURIER' => const Color(0xFF2563EB),
  'PREPARING' || 'READY' => const Color(0xFFF59E0B),
  'ACCEPTED' || 'ON_THE_WAY' => const Color(0xFF0891B2),
  'DELIVERED' || 'COMPLETED' => const Color(0xFF16A34A),
  'CANCELLED' => const Color(0xFFDC2626),
  _ => const Color(0xFF6B7280),
};
