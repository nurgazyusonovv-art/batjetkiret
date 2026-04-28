import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _report;
  int _reportDays = 7;
  bool _loading = true;
  bool _togglingOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getReports(days: _reportDays),
      ]);
      if (mounted) {
        setState(() {
          _me = results[0] as Map<String, dynamic>;
          _report = results[1] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReport() async {
    try {
      final r = await ApiService.getReports(days: _reportDays);
      if (mounted) setState(() => _report = r);
    } catch (_) {}
  }

  Future<void> _toggleOpen(bool? current) async {
    setState(() => _togglingOpen = true);
    try {
      final next = !(current ?? false);
      await ApiService.setOpenStatus(next);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _togglingOpen = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Чыгуу'),
        content: const Text('Системадан чыгууну каалайсызбы?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Чыгуу', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.deleteToken();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _me?['enterprise'] as Map<String, dynamic>?;
    final isOpen = e?['is_open'] as bool?;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: const Text('Профиль',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Enterprise card
                  if (e != null) _enterpriseCard(e, isOpen),
                  const SizedBox(height: 14),

                  // Report period selector
                  _reportSection(),
                  const SizedBox(height: 14),

                  // History link
                  _menuTile(
                    icon: Icons.history,
                    label: 'Заказдар тарыхы',
                    color: const Color(0xFF2563EB),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const _HistoryScreen())),
                  ),
                  const SizedBox(height: 8),

                  // Logout
                  _menuTile(
                    icon: Icons.logout,
                    label: 'Системадан чыгуу',
                    color: const Color(0xFFDC2626),
                    onTap: _logout,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _enterpriseCard(Map<String, dynamic> e, bool? isOpen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront,
                color: Color(0xFF16A34A), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e['name'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              Text(e['category'] as String? ?? '',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
              if (e['address'] != null)
                Text(e['address'] as String,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
            ],
          )),
        ]),
        const Divider(height: 20),
        Row(children: [
          const Text('Ишкана статусу:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_togglingOpen)
            const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            GestureDetector(
              onTap: () => _toggleOpen(isOpen),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpen == true
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOpen == true ? '🟢 Ачык' : '🔴 Жабык',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),
        ]),
        if (e['open_time'] != null || e['close_time'] != null) ...[
          const SizedBox(height: 6),
          Text(
            'Иш убактысы: ${e['open_time'] ?? '?'} – ${e['close_time'] ?? '?'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ]),
    );
  }

  Widget _reportSection() {
    final r = _report;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📊 Отчёт',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1к', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 7, label: Text('7к', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 30, label: Text('30к', style: TextStyle(fontSize: 11))),
            ],
            selected: {_reportDays},
            onSelectionChanged: (s) {
              setState(() => _reportDays = s.first);
              _loadReport();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xFF16A34A)
                      : null),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.white
                      : null),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (r != null) ...[
          _reportRow('Жалпы заказ', '${r['total_orders'] ?? 0}',
              const Color(0xFF2563EB)),
          _reportRow('Аяктаган', '${r['completed_orders'] ?? 0}',
              const Color(0xFF16A34A)),
          _reportRow('Жокко чыгарылган', '${r['cancelled_orders'] ?? 0}',
              const Color(0xFFDC2626)),
          _reportRow(
              'Жалпы киреше',
              '${(r['total_revenue'] as num?)?.toStringAsFixed(0) ?? 0} сом',
              const Color(0xFF7C3AED)),
          const Divider(height: 16),
          _reportRow('Онлайн заказ', '${r['online_orders'] ?? 0}',
              const Color(0xFF0891B2)),
          _reportRow('Жергиликтүү', '${r['local_orders'] ?? 0}',
              const Color(0xFFF59E0B)),
          _reportRow('Стол', '${r['dine_in_orders'] ?? 0}',
              const Color(0xFF7C3AED)),
        ],
      ]),
    );
  }

  static Widget _reportRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(width: 4, height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: color)),
    ]),
  );

  static Widget _menuTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ]),
        ),
      );
}

// ─── History Screen ───────────────────────────────────────────────────────────

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen();
  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getHistory();
      if (mounted) setState(() { _history = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        toolbarHeight: 48,
        title: const Text('Заказдар тарыхы',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _history.isEmpty
                  ? const Center(
                      child: Text('Тарых жок',
                          style: TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final o = _history[i] as Map<String, dynamic>;
                        final status = o['status'] as String? ?? '';
                        final id = o['id'];
                        final to = o['to_address'] ?? '';
                        final total = (o['items_total'] as num?)
                                ?.toStringAsFixed(0) ??
                            (o['price'] as num?)?.toStringAsFixed(0) ??
                            '0';
                        final createdAt =
                            (o['created_at'] as String? ?? '');
                        final isCompleted =
                            status == 'COMPLETED' || status == 'DELIVERED';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: (isCompleted
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626))
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: isCompleted
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Заказ #$id',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text(to,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280))),
                                if (createdAt.length >= 16)
                                  Text(
                                    createdAt
                                        .replaceAll('T', ' ')
                                        .substring(0, 16),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                              ],
                            )),
                            Text('$total сом',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}
