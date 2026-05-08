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

  void _openOrderSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderSheet(
        initialOrder: order,
        onChanged: () => _load(silent: true),
      ),
    );
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
          ...list.take(5).map((o) => GestureDetector(
                onTap: () => _openOrderSheet(o),
                child: _ActiveOrderTile(order: o),
              )),
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

// ─── Order Bottom Sheet ───────────────────────────────────────────────────────

class _OrderSheet extends StatefulWidget {
  final Map<String, dynamic> initialOrder;
  final VoidCallback onChanged;
  const _OrderSheet({required this.initialOrder, required this.onChanged});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late Map<String, dynamic> _order;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _refresh();
  }

  String get _status => _order['status'] as String? ?? '';
  String get _orderType => _order['order_type'] as String? ?? 'delivery';

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await ApiService.getOrderDetail(_order['id'] as int);
      if (mounted) setState(() { _order = fresh; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _nextStatuses => switch (_status) {
        'PREPARING'       => ['READY', 'CANCELLED'],
        'READY'           => ['WAITING_COURIER', 'CANCELLED'],
        'WAITING_COURIER' => ['CANCELLED'],
        _                 => [],
      };

  Future<void> _changeStatus(String next) async {
    if (next == 'CANCELLED') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Жокко чыгаруу'),
          content: const Text('Заказды жокко чыгарууну каалайсызбы?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Жок')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Ооба', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _updating = true);
    try {
      await ApiService.updateOrderStatus(_order['id'] as int, next);
      widget.onChanged();
      if (mounted) {
        setState(() {
          _order = {..._order, 'status': next};
          _updating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${OrdersScreen.statusLabel(next)}'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ));
        if (next == 'COMPLETED' || next == 'CANCELLED') {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Ката кетти'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }

  List<_SheetItem> _parseItems() {
    final desc = _order['description'] as String? ?? '';
    final items = <_SheetItem>[];
    for (final line in desc.split('\n')) {
      if (line.trim().isEmpty || line.startsWith('Эскертүү:')) continue;
      final m = RegExp(r'^(.+?)\s+x(\d+)\s*=\s*([\d.]+)\s*сом$').firstMatch(line.trim());
      if (m != null) {
        items.add(_SheetItem(m.group(1)!, int.parse(m.group(2)!), double.parse(m.group(3)!)));
      }
    }
    return items;
  }

  String? _parseNote() {
    for (final line in (_order['description'] as String? ?? '').split('\n')) {
      if (line.startsWith('Эскертүү:')) return line.substring('Эскертүү:'.length).trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _order['id'];
    final status = _status;
    final color = OrdersScreen.statusColor(status);
    final user = _order['user_name'] ?? _order['user_phone'] ?? 'Кардар';
    final phone = _order['user_phone'] as String? ?? '';
    final to = _order['to_address'] as String? ?? '';
    final courier = _order['courier_name'] as String?;
    final courierPhone = _order['courier_phone'] as String?;
    final source = _order['source'] as String? ?? '';
    final itemsTotal = (_order['items_total'] as num?)?.toStringAsFixed(0);
    final delivery = (_order['price'] as num?)?.toStringAsFixed(0) ?? '0';
    final createdAt = _order['created_at'] as String? ?? '';
    final items = _parseItems();
    final note = _parseNote();
    final nexts = _nextStatuses;
    // For online orders: raw description text (when structured parsing yields nothing)
    final rawDesc = items.isEmpty
        ? (_order['description'] as String? ?? '')
            .split('\n')
            .where((l) => !l.startsWith('Эскертүү:'))
            .join('\n')
            .trim()
        : '';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(children: [
              Text('Заказ #$id',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(OrdersScreen.statusLabel(status),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6B7280)),
                  onPressed: _refresh,
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 22, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          const Divider(height: 1),

          // Scrollable body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(14),
              children: [
                // Meta row
                Row(children: [
                  _sourceChip(source, _orderType),
                  const SizedBox(width: 8),
                  if (createdAt.length >= 16)
                    Text(createdAt.replaceAll('T', ' ').substring(0, 16),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
                const SizedBox(height: 10),

                // Customer card
                _card([
                  _sectionTitle('Кардар маалыматы'),
                  const SizedBox(height: 10),
                  _row(Icons.person_outline, user),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _row(Icons.phone_outlined, phone),
                  ],
                  if (to.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _row(Icons.location_on_outlined, to),
                  ],
                  if (courier != null) ...[
                    const Divider(height: 14),
                    _row(Icons.delivery_dining,
                        '$courier${courierPhone != null ? "  $courierPhone" : ""}',
                        color: const Color(0xFF2563EB)),
                  ],
                ]),
                const SizedBox(height: 10),

                // Items / description card
                _card([
                  Row(children: [
                    _sectionTitle(items.isNotEmpty ? '🛍 Товарлар' : '📋 Заказ мазмуну'),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                  ]),
                  const SizedBox(height: 10),

                  // Structured items (local orders)
                  if (items.isNotEmpty)
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${item.qty}×',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Text('${item.total.toStringAsFixed(0)} с',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF111827))),
                      ]),
                    ))

                  // Raw description (online orders)
                  else if (rawDesc.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(rawDesc,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF374151))),
                    )

                  // Loading placeholder
                  else if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text('Жүктөлүүдө...',
                            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      ),
                    )

                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Маалымат жок',
                          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                    ),

                  // Totals — always shown when available
                  if (itemsTotal != null || delivery != '0') ...[
                    const Divider(height: 18),
                    if (itemsTotal != null)
                      _totalRow('Товарлар суммасы', '$itemsTotal сом',
                          const Color(0xFF16A34A)),
                    if (delivery != '0')
                      _totalRow('Жеткирүү', '$delivery сом',
                          const Color(0xFF6B7280)),
                    _totalRow(
                      'Жалпы',
                      itemsTotal != null && delivery != '0'
                          ? '${(double.parse(itemsTotal) + double.parse(delivery)).toStringAsFixed(0)} сом'
                          : '${itemsTotal ?? delivery} сом',
                      const Color(0xFF111827),
                      big: true,
                    ),
                  ],
                ]),

                // Note
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _card([
                    _sectionTitle('Эскертүү'),
                    const SizedBox(height: 8),
                    Text(note, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                  ]),
                ],

                // Status buttons
                if (nexts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...nexts.map((s) {
                    final c = OrdersScreen.statusColor(s);
                    final isCancelled = s == 'CANCELLED';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _updating ? null : () => _changeStatus(s),
                          icon: _updating
                              ? SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2,
                                      color: isCancelled ? const Color(0xFFDC2626) : Colors.white))
                              : Icon(_statusIcon(s), size: 20,
                                  color: isCancelled ? const Color(0xFFDC2626) : Colors.white),
                          label: Text(OrdersScreen.statusLabel(s),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  color: isCancelled ? const Color(0xFFDC2626) : Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCancelled ? const Color(0xFFFEF2F2) : c,
                            side: isCancelled ? const BorderSide(color: Color(0xFFFCA5A5)) : BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static IconData _statusIcon(String s) => switch (s) {
        'READY'           => Icons.check_circle_outline,
        'WAITING_COURIER' => Icons.delivery_dining,
        'COMPLETED'       => Icons.done_all,
        'CANCELLED'       => Icons.cancel_outlined,
        _                 => Icons.arrow_forward,
      };

  static Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  static Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280)));

  static Widget _row(IconData icon, String text, {Color? color}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color ?? const Color(0xFF374151)))),
        ],
      );

  static Widget _totalRow(String label, String value, Color color, {bool big = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(fontSize: big ? 14 : 13,
                  fontWeight: big ? FontWeight.w700 : FontWeight.normal,
                  color: const Color(0xFF374151)))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: big ? 16 : 14, color: color)),
        ]),
      );

  static Widget _sourceChip(String source, String orderType) {
    final (label, color) = switch (source) {
      'online' => ('Онлайн', const Color(0xFF2563EB)),
      'local'  => ('Жергиликтүү', const Color(0xFFDC2626)),
      _        => (orderType == 'dine_in' ? 'Стол' : 'Жеткирүү', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SheetItem {
  final String name;
  final int qty;
  final double total;
  const _SheetItem(this.name, this.qty, this.total);
}

// ─── Active Order Tile ────────────────────────────────────────────────────────

class _ActiveOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ActiveOrderTile({required this.order});

  int get _itemCount {
    final desc = order['description'] as String? ?? '';
    if (desc.isEmpty) return 0;
    final rx = RegExp(r'^.+\s+x\d+\s*=\s*[\d.]+\s*сом$');
    return desc.split('\n').where((l) => rx.hasMatch(l.trim())).length;
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? '';
    final id = order['id'];
    final to = order['to_address'] as String? ?? '';
    final user = order['user_name'] ?? order['user_phone'] ?? '';
    final total = (order['items_total'] as num?)?.toStringAsFixed(0) ??
        (order['price'] as num?)?.toStringAsFixed(0) ??
        '0';
    final count = _itemCount;

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
        // Order number badge
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('#$id',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status))),
            if (count > 0)
              Text('$count п.',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: _statusColor(status).withValues(alpha: 0.8))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (to.isNotEmpty)
                Text(to,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              Text(user.toString(),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
              // Mini item list preview
              if (count > 0)
                _itemPreview(),
            ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total с',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: Color(0xFF111827))),
          const SizedBox(height: 3),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(OrdersScreen.statusLabel(status),
                style: TextStyle(
                    fontSize: 10, color: _statusColor(status),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 2),
          const Text('Толугун көрүү →',
              style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
        ]),
      ]),
    );
  }

  Widget _itemPreview() {
    final desc = order['description'] as String? ?? '';
    if (desc.isEmpty) return const SizedBox.shrink();
    final rx = RegExp(r'^(.+?)\s+x(\d+)\s*=\s*([\d.]+)\s*сом$');
    final structuredLines = desc
        .split('\n')
        .where((l) => rx.hasMatch(l.trim()))
        .take(2)
        .toList();

    // Structured items (local orders)
    if (structuredLines.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: structuredLines.map((line) {
            final m = rx.firstMatch(line.trim());
            if (m == null) return const SizedBox.shrink();
            return Text(
              '${m.group(2)}× ${m.group(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            );
          }).toList(),
        ),
      );
    }

    // Raw description (online orders)
    final rawLine = desc
        .split('\n')
        .where((l) => !l.startsWith('Эскертүү:') && l.trim().isNotEmpty)
        .join(', ');
    if (rawLine.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        rawLine,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
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
