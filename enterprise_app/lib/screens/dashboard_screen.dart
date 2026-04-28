import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/notification_service.dart';
import 'orders_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onGoToOrders;
  const DashboardScreen({super.key, this.onGoToOrders});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _togglingOpen = false;
  Timer? _timer;
  Set<int> _knownOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(
        const Duration(seconds: 30), (_) => _load(silent: true));
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

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final s = await ApiService.getStats();
      if (!mounted) return;

      final list =
          (s['active_orders_list'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      final currentIds = list.map<int>((o) => o['id'] as int).toSet();

      // Show notification for each new order
      if (_knownOrderIds.isNotEmpty) {
        for (final id in currentIds.difference(_knownOrderIds)) {
          final o = list.firstWhere((x) => x['id'] == id);
          final addr = o['to_address'] as String? ?? '';
          await NotificationService.show('🛎 Жаңы заказ #$id', addr);
        }
      }
      _knownOrderIds = currentIds;

      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOpen() async {
    final s = _stats;
    if (s == null) return;
    final enterprise = s['enterprise'] as Map<String, dynamic>?;
    final current = enterprise?['is_open'] as bool? ?? false;

    setState(() => _togglingOpen = true);
    try {
      final result = await ApiService.setOpenStatus(!current);
      if (mounted) {
        setState(() {
          (_stats!['enterprise'] as Map<String, dynamic>)['is_open'] = result;
          _togglingOpen = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _togglingOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final enterprise = s?['enterprise'] as Map<String, dynamic>?;
    final isOpen = enterprise?['is_open'] as bool? ?? false;
    final name = enterprise?['name'] as String? ?? 'Ишкана';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const Text('Башкы бет',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _OpenStatusCard(
                    isOpen: isOpen,
                    toggling: _togglingOpen,
                    openTime: enterprise?['open_time'] as String?,
                    closeTime: enterprise?['close_time'] as String?,
                    onTap: _toggleOpen,
                  ),
                  const SizedBox(height: 14),
                  if (s != null) ...[
                    _todaySection(s),
                    const SizedBox(height: 16),
                    _activeOrdersSection(s),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _todaySection(Map<String, dynamic> s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('🗓 Бүгүн'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _StatCard(
                icon: Icons.receipt_long,
                label: 'Жалпы заказ',
                value: '${s['total_orders'] ?? 0}',
                color: const Color(0xFF2563EB)),
            _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Аяктаган',
                value: '${s['completed_orders'] ?? 0}',
                color: const Color(0xFF16A34A)),
            _StatCard(
                icon: Icons.hourglass_empty,
                label: 'Жеткирүүдө',
                value: '${s['pending_orders'] ?? 0}',
                color: const Color(0xFFF59E0B)),
            _StatCard(
                icon: Icons.monetization_on_outlined,
                label: 'Киреше',
                value:
                    '${(s['total_revenue'] as num?)?.toStringAsFixed(0) ?? 0} с',
                color: const Color(0xFF7C3AED)),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _StatCard(
                icon: Icons.wifi,
                label: 'Онлайн заказ',
                value: '${s['online_orders'] ?? 0}',
                color: const Color(0xFF0891B2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
                icon: Icons.store,
                label: 'Жергиликтүү',
                value: '${s['local_orders'] ?? 0}',
                color: const Color(0xFFDC2626)),
          ),
        ]),
      ],
    );
  }

  Widget _activeOrdersSection(Map<String, dynamic> s) {
    final list =
        (s['active_orders_list'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _Label('🔥 Активдүү заказдар'),
          const Spacer(),
          if (list.isNotEmpty)
            GestureDetector(
              onTap: widget.onGoToOrders,
              child: const Text('Баарын көрүү →',
                  style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 6),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Активдүү заказ жок',
                  style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
          )
        else
          ...list.take(5).map((o) => _ActiveOrderTile(order: o)),
      ],
    );
  }
}

// ─── Open Status Card ─────────────────────────────────────────────────────────

class _OpenStatusCard extends StatelessWidget {
  final bool isOpen;
  final bool toggling;
  final String? openTime;
  final String? closeTime;
  final VoidCallback onTap;

  const _OpenStatusCard({
    required this.isOpen,
    required this.toggling,
    required this.openTime,
    required this.closeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor =
        isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOpen ? Icons.storefront : Icons.storefront_outlined,
            color: color,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? '🟢 Ишкана ачык' : '🔴 Ишкана жабык',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color),
                ),
                if (openTime != null || closeTime != null)
                  Text(
                    'Иш убактысы: ${openTime ?? '?'} – ${closeTime ?? '?'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  )
                else
                  Text(
                    isOpen
                        ? 'Кардарларды кабыл алууда'
                        : 'Азыр заказ кабыл алынбайт',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
              ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: toggling ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: toggling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    isOpen ? 'Жабуу' : 'Ачуу',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
          ),
        ),
      ]),
    );
  }
}

// ─── Active Order Tile ────────────────────────────────────────────────────────

class _ActiveOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActiveOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final id = order['id'];
    final to = order['to_address'] ?? '';
    final user = order['user_name'] ?? order['user_phone'] ?? '';
    final total = (order['items_total'] as num?)?.toStringAsFixed(0) ??
        (order['price'] as num?)?.toStringAsFixed(0) ??
        '0';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('#$id',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(to,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(user,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
            ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total с',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(OrdersScreen.statusLabel(status),
                style: TextStyle(
                    fontSize: 10, color: _statusColor(status))),
          ),
        ]),
      ]),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'PREPARING' => const Color(0xFFF59E0B),
        'READY' => const Color(0xFF16A34A),
        'WAITING_COURIER' => const Color(0xFF2563EB),
        'ACCEPTED' || 'ON_THE_WAY' => const Color(0xFF0891B2),
        _ => const Color(0xFF6B7280),
      };
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280)));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}
