import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _order;
  bool _loading = false;
  bool _updating = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refresh();
  }

  String get _status => _order['status'] as String? ?? '';
  String get _orderType => _order['order_type'] as String? ?? 'delivery';

  Future<void> _refresh() async {
    try {
      final fresh = await ApiService.getOrderDetail(_order['id'] as int);
      if (mounted) setState(() => _order = fresh);
    } catch (_) {}
  }

  List<String> get _nextStatuses {
    if (_orderType == 'dine_in') {
      return switch (_status) {
        'PREPARING' => ['READY', 'COMPLETED', 'CANCELLED'],
        'READY' => ['COMPLETED', 'CANCELLED'],
        _ => [],
      };
    }
    return switch (_status) {
      'PREPARING' => ['READY', 'CANCELLED'],
      'READY' => ['WAITING_COURIER', 'CANCELLED'],
      'WAITING_COURIER' => ['CANCELLED'],
      _ => [],
    };
  }

  Future<void> _changeStatus(String next) async {
    final isCancelled = next == 'CANCELLED';
    if (isCancelled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Жокко чыгаруу'),
          content: const Text('Заказды жокко чыгарууну каалайсызбы?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жок'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text(
                'Ооба, жокко чыгар',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _updating = true);
    try {
      await ApiService.updateOrderStatus(_order['id'] as int, next);
      _changed = true;
      if (mounted) {
        setState(() {
          _order = {..._order, 'status': next};
          _updating = false;
        });
        _showSnack(
          '✅ Статус өзгөртүлдү: ${OrdersScreen.statusLabel(next)}',
          const Color(0xFF16A34A),
        );
        if (next == 'COMPLETED' || next == 'CANCELLED') {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _updating = false);
        _showSnack('❌ Статус өзгөртүлбөдү', const Color(0xFFDC2626));
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<_ParsedItem> _parseItems() {
    final desc = _order['description'] as String? ?? '';
    if (desc.isEmpty) return [];
    final items = <_ParsedItem>[];
    for (final line in desc.split('\n')) {
      if (line.trim().isEmpty || line.startsWith('Эскертүү:')) continue;
      final match = RegExp(
        r'^(.+?)\s+x(\d+)\s*=\s*([\d.]+)\s*сом$',
      ).firstMatch(line.trim());
      if (match != null) {
        items.add(
          _ParsedItem(
            name: match.group(1)!,
            qty: int.parse(match.group(2)!),
            total: double.parse(match.group(3)!),
          ),
        );
      } else {
        items.add(_ParsedItem(name: line.trim(), qty: 0, total: 0));
      }
    }
    return items;
  }

  String? _parseNote() {
    final desc = _order['description'] as String? ?? '';
    for (final line in desc.split('\n')) {
      if (line.startsWith('Эскертүү:')) {
        return line.substring('Эскертүү:'.length).trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _order['id'];
    final status = _status;
    final color = OrdersScreen.statusColor(status);
    final items = _parseItems();
    final note = _parseNote();
    final user = _order['user_name'] ?? _order['user_phone'] ?? 'Кардар';
    final phone = _order['user_phone'] as String? ?? '';
    final courier = _order['courier_name'] as String?;
    final courierPhone = _order['courier_phone'] as String?;
    final to = _order['to_address'] as String? ?? '';
    final tableNum = _order['table_number'];
    final source = _order['source'] as String? ?? '';
    final itemsTotal = (_order['items_total'] as num?)?.toStringAsFixed(0);
    final delivery = (_order['price'] as num?)?.toStringAsFixed(0) ?? '0';
    final createdAt = (_order['created_at'] as String? ?? '');
    final nexts = _nextStatuses;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          toolbarHeight: 48,
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          title: Text(
            'Заказ #$id',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          actions: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  setState(() => _loading = true);
                  _refresh().then((_) {
                    if (mounted) setState(() => _loading = false);
                  });
                },
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Status banner
            _card([
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      OrdersScreen.statusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sourceChip(source, _orderType),
                  const Spacer(),
                  if (createdAt.length >= 16)
                    Text(
                      createdAt.replaceAll('T', ' ').substring(0, 16),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 10),

            // Customer info
            _card([
              _sectionTitle('Кардар маалыматы'),
              const SizedBox(height: 10),
              _row(Icons.person_outline, user),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                _row(Icons.phone_outlined, phone),
              ],
              if (tableNum != null) ...[
                const SizedBox(height: 6),
                _row(Icons.table_restaurant_outlined, 'Стол №$tableNum'),
              ] else if (to.isNotEmpty) ...[
                const SizedBox(height: 6),
                _row(Icons.location_on_outlined, to),
              ],
              if (courier != null) ...[
                const Divider(height: 16),
                _row(
                  Icons.delivery_dining,
                  '$courier${courierPhone != null ? "  $courierPhone" : ""}',
                  color: const Color(0xFF2563EB),
                ),
              ],
            ]),
            const SizedBox(height: 10),

            // Items
            if (items.isNotEmpty)
              _card([
                _sectionTitle('Товарлар'),
                const SizedBox(height: 10),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (item.qty > 0)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${item.qty}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (item.total > 0)
                          Text(
                            '${item.total.toStringAsFixed(0)} с',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),
                if (itemsTotal != null)
                  _totalRow(
                    'Товарлар суммасы',
                    '$itemsTotal сом',
                    const Color(0xFF16A34A),
                  ),
                if (delivery != '0')
                  _totalRow(
                    'Жеткирүү акысы',
                    '$delivery сом',
                    const Color(0xFF6B7280),
                  ),
                _totalRow(
                  'Жалпы',
                  itemsTotal != null && delivery != '0'
                      ? '${(double.parse(itemsTotal) + double.parse(delivery)).toStringAsFixed(0)} сом'
                      : '${itemsTotal ?? delivery} сом',
                  const Color(0xFF111827),
                  big: true,
                ),
              ]),

            // Note
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 10),
              _card([
                _sectionTitle('Эскертүү'),
                const SizedBox(height: 8),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ]),
            ],


            // Status change buttons
            if (nexts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Статусту өзгөртүү',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
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
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isCancelled
                                    ? const Color(0xFFDC2626)
                                    : Colors.white,
                              ),
                            )
                          : Icon(
                              _statusIcon(s),
                              size: 20,
                              color: isCancelled
                                  ? const Color(0xFFDC2626)
                                  : Colors.white,
                            ),
                      label: Text(
                        OrdersScreen.statusLabel(s),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isCancelled
                              ? const Color(0xFFDC2626)
                              : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCancelled
                            ? const Color(0xFFFEF2F2)
                            : c,
                        side: isCancelled
                            ? const BorderSide(color: Color(0xFFFCA5A5))
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: OrdersScreen.statusColor(status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${OrdersScreen.statusLabel(status)} — өзгөртүүгө болбойт',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(String s) => switch (s) {
    'READY' => Icons.check_circle_outline,
    'WAITING_COURIER' => Icons.delivery_dining,
    'COMPLETED' => Icons.done_all,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.arrow_forward,
  };

  static Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Color(0xFF6B7280),
    ),
  );

  static Widget _row(IconData icon, String text, {Color? color}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color ?? const Color(0xFF9CA3AF)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color ?? const Color(0xFF374151),
          ),
        ),
      ),
    ],
  );

  static Widget _totalRow(
    String label,
    String value,
    Color color, {
    bool big = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: big ? 14 : 13,
              fontWeight: big ? FontWeight.w700 : FontWeight.normal,
              color: const Color(0xFF374151),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: big ? 16 : 14,
            color: color,
          ),
        ),
      ],
    ),
  );

  static Widget _sourceChip(String source, String orderType) {
    final (label, color) = switch (source) {
      'online' => ('Онлайн', const Color(0xFF2563EB)),
      'dine_in' => ('Стол', const Color(0xFF7C3AED)),
      'local' => ('Жергиликтүү', const Color(0xFFDC2626)),
      _ => (
        orderType == 'dine_in' ? 'Стол' : 'Жеткирүү',
        const Color(0xFF6B7280),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ParsedItem {
  final String name;
  final int qty;
  final double total;
  const _ParsedItem({
    required this.name,
    required this.qty,
    required this.total,
  });
}
