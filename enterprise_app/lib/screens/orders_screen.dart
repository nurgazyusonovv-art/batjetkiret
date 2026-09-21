import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/notification_service.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  static String statusLabel(String s) => switch (s) {
    'WAITING_COURIER' => 'Курьер күтүлүүдө',
    'PREPARING'       => 'Даярдалууда',
    'READY'           => 'Даяр',
    'ACCEPTED'        => 'Кабыл алынды',
    'ON_THE_WAY'      => 'Жолдо',
    'COMPLETED'       => 'Аяктады',
    'DELIVERED'       => 'Жеткирилди',
    'CANCELLED'       => 'Жокко чыгарылды',
    _                 => s,
  };

  static Color statusColor(String s) => switch (s) {
    'PREPARING'                    => const Color(0xFFF59E0B),
    'READY'                        => const Color(0xFF16A34A),
    'WAITING_COURIER'              => const Color(0xFF2563EB),
    'ACCEPTED' || 'ON_THE_WAY'    => const Color(0xFF0891B2),
    'COMPLETED' || 'DELIVERED'    => const Color(0xFF6B7280),
    'CANCELLED'                    => const Color(0xFFDC2626),
    _                              => const Color(0xFF9CA3AF),
  };

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  Set<int> _knownIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _pollForNew());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _pollForNew() async {
    try {
      final data = await ApiService.getOrders();
      final newIds = data.map<int>((o) => o['id'] as int).toSet();
      if (_knownIds.isNotEmpty) {
        for (final id in newIds.difference(_knownIds)) {
          final o = data.firstWhere((x) => x['id'] == id);
          final addr = o['to_address'] ?? '';
          await NotificationService.show(
            '🛎 Жаңы заказ #$id', addr);
        }
      }
      _knownIds = newIds;
      if (mounted) setState(() => _orders = data);
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getOrders();
      _knownIds = data.map<int>((o) => o['id'] as int).toSet();
      if (mounted) setState(() { _orders = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  Future<void> _changeStatus(int id, String current, String orderType) async {
    final next = _nextStatuses(current, orderType);
    if (next.isEmpty) return;

    String? chosen;
    if (next.length == 1) {
      chosen = next.first;
    } else {
      chosen = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => _StatusPicker(statuses: next),
      );
    }
    if (chosen == null) return;

    try {
      await ApiService.updateOrderStatus(id, chosen);
      _load(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Статус өзгөртүлбөдү')));
      }
    }
  }

  List<String> _nextStatuses(String current, String orderType) {
    if (orderType == 'dine_in') {
      return switch (current) {
        'PREPARING'  => ['READY', 'CANCELLED'],
        'READY'      => ['COMPLETED', 'CANCELLED'],
        _            => [],
      };
    }
    return switch (current) {
      'PREPARING'       => ['READY', 'CANCELLED'],
      'READY'           => ['WAITING_COURIER', 'CANCELLED'],
      'WAITING_COURIER' => ['CANCELLED'],
      _                 => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('Активдүү заказдар',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (_orders.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Text('${_orders.length}',
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 18),
              onPressed: _load, padding: EdgeInsets.zero),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : _orders.isEmpty
                    ? _emptyView()
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          return _OrderCard(
                            order: o,
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(order: o),
                                ),
                              );
                              if (changed == true) _load(silent: true);
                            },
                            onStatusTap: () => _changeStatus(
                              o['id'] as int,
                              o['status'] as String? ?? '',
                              o['order_type'] as String? ?? 'delivery',
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _errorView() => ListView(children: [
    const SizedBox(height: 200),
    Center(child: Column(children: [
      Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _load, child: const Text('Кайра')),
    ])),
  ]);

  Widget _emptyView() => ListView(children: const [
    SizedBox(height: 200),
    Center(child: Column(children: [
      Icon(Icons.inbox_outlined, size: 60, color: Color(0xFFD1D5DB)),
      SizedBox(height: 12),
      Text('Азырынча активдүү заказ жок',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
    ])),
  ]);
}

class _OrderCard extends StatelessWidget {
  final dynamic order;
  final VoidCallback onTap;
  final VoidCallback onStatusTap;
  const _OrderCard({required this.order, required this.onTap, required this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    final id = order['id'];
    final status = order['status'] as String? ?? '';
    final orderType = order['order_type'] as String? ?? 'delivery';
    final to = order['to_address'] ?? '';
    final user = order['user_name'] ?? order['user_phone'] ?? 'Кардар';
    final userPhone = order['user_phone'] ?? '';
    final courier = order['courier_name'] as String?;
    final itemsTotal = (order['items_total'] as num?)?.toStringAsFixed(0);
    final price = (order['price'] as num?)?.toStringAsFixed(0) ?? '0';
    final createdAt = (order['created_at'] as String? ?? '');
    final source = order['source'] as String? ?? '';
    final color = OrdersScreen.statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Text('Заказ #$id',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 8),
            _sourceChip(source, orderType),
            const Spacer(),
            if (itemsTotal != null)
              Text('$itemsTotal сом',
                  style: TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 15, color: color))
            else
              Text('$price сом',
                  style: TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 15, color: color)),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row(Icons.location_on_outlined, to),
            const SizedBox(height: 4),
            _row(Icons.person_outline, user +
                (userPhone.isNotEmpty ? '  $userPhone' : '')),
            if (courier != null) ...[
              const SizedBox(height: 4),
              _row(Icons.delivery_dining, courier),
            ],
            if (createdAt.length >= 16) ...[
              const SizedBox(height: 4),
              _row(Icons.access_time,
                  createdAt.replaceAll('T', ' ').substring(0, 16)),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onStatusTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(OrdersScreen.statusLabel(status),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ));
  }

  static Widget _row(IconData icon, String text) => Row(children: [
    Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
    const SizedBox(width: 6),
    Expanded(child: Text(text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        maxLines: 2, overflow: TextOverflow.ellipsis)),
  ]);

  static Widget _sourceChip(String source, String orderType) {
    final (label, color) = switch (source) {
      'online'   => ('Онлайн', const Color(0xFF2563EB)),
      'dine_in'  => ('Стол', const Color(0xFF7C3AED)),
      'local'    => ('Жергиликтүү', const Color(0xFFDC2626)),
      _          => (orderType == 'dine_in' ? 'Стол' : 'Жеткирүү',
                     const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  final List<String> statuses;
  const _StatusPicker({required this.statuses});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Статусту өзгөртүү',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...statuses.map((s) {
            final color = OrdersScreen.statusColor(s);
            return ListTile(
              leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(Icons.circle, size: 10, color: color)),
              title: Text(OrdersScreen.statusLabel(s),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, s),
            );
          }),
        ]),
      ),
    );
  }
}
