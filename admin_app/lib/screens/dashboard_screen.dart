import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _stats;
  List<dynamic> _trend = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getStats(),
        ApiService.getRevenueTrend(days: 7),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _trend = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        title: const Text('Дашборд',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        actions: [
          if (_stats != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.circle,
                  size: 10,
                  color: Colors.greenAccent.withValues(alpha: 0.9)),
            ),
          IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _load,
              padding: EdgeInsets.zero),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Кайра')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      _SectionLabel('🗓 Бүгүн'),
                      const SizedBox(height: 8),
                      _todayGrid(),
                      const SizedBox(height: 16),
                      _SectionLabel('👥 Колдонуучулар & Курьерлер'),
                      const SizedBox(height: 8),
                      _usersRow(),
                      const SizedBox(height: 16),
                      _SectionLabel('💳 Топап (баары)'),
                      const SizedBox(height: 8),
                      _topupRow(),
                      const SizedBox(height: 16),
                      _SectionLabel('📈 Соңку 7 күн — аяктаган заказдар'),
                      const SizedBox(height: 8),
                      _TrendChart(trend: _trend),
                      const SizedBox(height: 16),
                      _SectionLabel('📦 Жалпы'),
                      const SizedBox(height: 8),
                      _allTimeRow(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }

  Widget _todayGrid() {
    final s = _stats!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _StatCard(
          icon: Icons.receipt_long,
          label: 'Жалпы заказ',
          value: '${s['total_orders_today'] ?? 0}',
          color: const Color(0xFF2563EB),
        ),
        _StatCard(
          icon: Icons.check_circle_outline,
          label: 'Аяктаганы',
          value: '${s['delivered_orders_today'] ?? 0}',
          color: const Color(0xFF16A34A),
        ),
        _StatCard(
          icon: Icons.cancel_outlined,
          label: 'Жокко чыгарылды',
          value: '${s['canceled_orders_today'] ?? 0}',
          color: const Color(0xFFDC2626),
        ),
        _StatCard(
          icon: Icons.monetization_on_outlined,
          label: 'Киреше',
          value: '${(s['revenue_today'] as num?)?.toStringAsFixed(0) ?? 0} с',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _usersRow() {
    final s = _stats!;
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Icons.people_outline,
          label: 'Колдонуучулар',
          value: '${s['total_users'] ?? 0}',
          color: const Color(0xFF7C3AED),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.delivery_dining,
          label: 'Курьерлер',
          value: '${s['total_couriers'] ?? 0}',
          color: const Color(0xFF0891B2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.circle,
          label: 'Онлайн',
          value: '${s['online_couriers'] ?? 0}',
          color: const Color(0xFF16A34A),
          iconSize: 14,
        ),
      ),
    ]);
  }

  Widget _topupRow() {
    final s = _stats!;
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Icons.hourglass_empty_outlined,
          label: 'Күтүлүүдө',
          value: '${s['pending_topups'] ?? 0}',
          color: const Color(0xFFF59E0B),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.check_circle_outline,
          label: 'Тастыкталды',
          value: '${(s['approved_topups_amount'] as num?)?.toStringAsFixed(0) ?? 0} с',
          color: const Color(0xFF16A34A),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.cancel_outlined,
          label: 'Четке кагылды',
          value: '${(s['rejected_topups_amount'] as num?)?.toStringAsFixed(0) ?? 0} с',
          color: const Color(0xFFDC2626),
        ),
      ),
    ]);
  }

  Widget _allTimeRow() {
    final s = _stats!;
    return Row(children: [
      Expanded(
        child: _StatCard(
          icon: Icons.receipt_long,
          label: 'Бардык заказ',
          value: '${s['total_orders'] ?? 0}',
          color: const Color(0xFF2563EB),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.done_all,
          label: 'Аяктаган',
          value: '${s['completed_orders'] ?? 0}',
          color: const Color(0xFF16A34A),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatCard(
          icon: Icons.savings_outlined,
          label: 'Жалпы киреше',
          value: '${(s['total_revenue'] as num?)?.toStringAsFixed(0) ?? 0} с',
          color: const Color(0xFFF59E0B),
        ),
      ),
    ]);
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280)));
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double iconSize;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.iconSize = 18,
  });

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
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: iconSize, color: color),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<dynamic> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Маалымат жок',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
      );
    }

    final maxOrders = trend
        .map((d) => (d['orders'] as num?)?.toDouble() ?? 0)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
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
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((d) {
                final orders = (d['orders'] as num?)?.toDouble() ?? 0;
                final revenue = (d['revenue'] as num?)?.toDouble() ?? 0;
                final date = (d['date'] as String? ?? '').length >= 10
                    ? (d['date'] as String).substring(5)
                    : '';
                final ratio = maxOrders > 0 ? orders / maxOrders : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (orders > 0)
                          Text('${orders.toInt()}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB))),
                        const SizedBox(height: 2),
                        Tooltip(
                          message: '${orders.toInt()} заказ\n${revenue.toStringAsFixed(0)} сом',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: (ratio * 72).clamp(4, 72),
                            decoration: BoxDecoration(
                              color: orders > 0
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(date,
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.monetization_on_outlined,
                size: 13, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
            Text(
              'Жалпы 7 күн: ${trend.fold<double>(0, (s, d) => s + ((d['revenue'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)} сом',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A)),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.receipt_long, size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              '${trend.fold<int>(0, (s, d) => s + ((d['orders'] as num?)?.toInt() ?? 0))} заказ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ]),
        ],
      ),
    );
  }
}
