import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../main.dart' show showLocalNotification;

class CancelRequestsScreen extends StatefulWidget {
  const CancelRequestsScreen({super.key});

  @override
  State<CancelRequestsScreen> createState() => _CancelRequestsScreenState();
}

class _CancelRequestsScreenState extends State<CancelRequestsScreen>
    with WidgetsBindingObserver {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  Set<int> _knownIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
    FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] ?? '';
      if (type == 'cancel_request') {
        _load(silent: true);
        final title = msg.data['title'] ?? '❌ Жокко чыгаруу суроосу';
        final body = msg.data['body'] ?? '';
        showLocalNotification(title, body);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  void _startPolling() {
    _pollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _pollForNew());
  }

  Future<void> _pollForNew() async {
    try {
      final data = await ApiService.getCancelRequests();
      final newIds = data.map<int>((r) => r['id'] as int).toSet();
      if (_knownIds.isNotEmpty) {
        for (final id in newIds.difference(_knownIds)) {
          final req = data.firstWhere((r) => r['id'] == id);
          final name = req['user_name'] ?? 'Колдонуучу';
          await showLocalNotification(
            '❌ Жокко чыгаруу суроосу',
            '$name — Заказ #$id',
          );
        }
      }
      _knownIds = newIds;
      if (mounted) setState(() => _requests = data);
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getCancelRequests();
      _knownIds = data.map<int>((r) => r['id'] as int).toSet();
      if (mounted) setState(() { _requests = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  Future<void> _approve(dynamic r) async {
    final orderId = r['id'] as int;
    final userName = r['user_name'] ?? 'Колдонуучу';
    final price = (r['price'] as num).toDouble();
    final defaultUserRefund = (r['user_refund_amount'] as num?)?.toDouble() ?? 5.0;
    final defaultCourierPayout = (r['courier_payout_amount'] as num?)?.toDouble() ?? 5.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Жокко чыгарууну тастыктоо'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Колдонуучу: $userName'),
            Text('Заказ суммасы: ${price.toStringAsFixed(0)} сом'),
            const SizedBox(height: 8),
            Text(
              'Колдонуучуга кайтарылат: ${defaultUserRefund.toStringAsFixed(0)} сом\n'
              'Курьерге төлөнөт: ${defaultCourierPayout.toStringAsFixed(0)} сом',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Тастыктоо',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.approveCancelRequest(orderId);
      _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Жокко чыгаруу тастыкталды'),
              backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ката: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(dynamic r) async {
    final orderId = r['id'] as int;
    final noteCtrl = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Четке кагуу'),
        content: TextField(
          controller: noteCtrl,
          decoration:
              const InputDecoration(hintText: 'Себебин жазыңыз (милдеттүү эмес)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Четке как',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (note == null) return;

    try {
      await ApiService.rejectCancelRequest(orderId, adminNote: note);
      _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Суроо четке кагылды')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ката: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Жокко чыгаруу суроолору',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (_requests.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_requests.length}',
                  style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _load,
              padding: EdgeInsets.zero),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 200),
                    Center(
                      child: Column(children: [
                        Text(_error!,
                            style:
                                const TextStyle(color: Color(0xFFDC2626))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Кайра')),
                      ]),
                    ),
                  ])
                : _requests.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('Жокко чыгаруу суроолору жок',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 16)),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) => _CancelCard(
                          data: _requests[i],
                          onApprove: () => _approve(_requests[i]),
                          onReject: () => _reject(_requests[i]),
                        ),
                      ),
      ),
    );
  }
}

class _CancelCard extends StatelessWidget {
  final dynamic data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CancelCard(
      {required this.data, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final orderId = data['id'] as int;
    final status = data['status'] as String? ?? '';
    final reason = data['cancel_request_reason'] as String?;
    final userName = data['user_name'] ?? 'Колдонуучу';
    final userPhone = data['user_phone'] ?? '';
    final courierName = data['courier_name'] as String?;
    final courierPhone = data['courier_phone'] as String?;
    final fromAddr = data['from_address'] ?? '';
    final toAddr = data['to_address'] ?? '';
    final price = (data['price'] as num).toDouble();
    final createdAt = (data['created_at'] ?? '').toString();
    final userRefund = (data['user_refund_amount'] as num?)?.toDouble() ?? 5.0;
    final courierPayout =
        (data['courier_payout_amount'] as num?)?.toDouble() ?? 5.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text('Заказ #$orderId',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusLabel(status),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ),
                const Spacer(),
                Text('${price.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF111827))),
              ],
            ),
            const SizedBox(height: 10),

            // User info
            _infoRow(Icons.person, '$userName  $userPhone'),

            // Courier info
            if (courierName != null)
              _infoRow(Icons.delivery_dining,
                  '$courierName${courierPhone != null ? "  $courierPhone" : ""}'),

            const SizedBox(height: 4),
            _infoRow(Icons.arrow_forward, '$fromAddr → $toAddr', small: true),

            if (createdAt.length >= 16)
              _infoRow(Icons.access_time,
                  createdAt.replaceAll('T', ' ').substring(0, 16),
                  small: true),

            // Reason
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reason,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF92400E))),
                    ),
                  ],
                ),
              ),
            ],

            // Financial preview
            const SizedBox(height: 10),
            Row(
              children: [
                _chip('↩ Кайтарылат: ${userRefund.toStringAsFixed(0)} с',
                    const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                _chip('→ Курьерге: ${courierPayout.toStringAsFixed(0)} с',
                    const Color(0xFF2563EB)),
              ],
            ),

            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Тастыктоо', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Четке как', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(IconData icon, String text, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(icon,
            size: small ? 13 : 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: small ? 12 : 13,
                  color: small
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF374151))),
        ),
      ]),
    );
  }

  static Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'ACCEPTED' => '🚴 Кабыл алынды',
        'ON_THE_WAY' => '🛵 Жолдо',
        _ => s,
      };
}
