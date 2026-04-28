import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _pending = [];
  List<dynamic> _confirmed = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPayments(status: 'pending'),
        ApiService.getPayments(status: 'confirmed'),
      ]);
      if (mounted) {
        setState(() {
          _pending = results[0];
          _confirmed = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(int paymentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Төлөмдү тастыктоо'),
        content: const Text('Бул төлөмдү тастыктайсызбы?\nЗаказдын статусу "Кабыл алынды"га өзгөрөт.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Тастыктоо', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.confirmPayment(paymentId);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Төлөм тастыкталды'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ката кетти'), backgroundColor: Color(0xFFDC2626),
        ));
      }
    }
  }

  Future<void> _reject(int paymentId) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Төлөмдү четке кагуу'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Себебин жазсаңыз болот (милдеттүү эмес):'),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              hintText: 'Себеп...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Четке кагуу', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.rejectPayment(paymentId,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Төлөм четке кагылды'),
          backgroundColor: Color(0xFFDC2626),
        ));
      }
    } catch (_) {}
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
          const Text('Төлөмдөр',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (_pending.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${_pending.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Күтүүдө${_pending.isNotEmpty ? " (${_pending.length})" : ""}'),
            const Tab(text: 'Тастыкталган'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _PaymentList(
                  payments: _pending,
                  isPending: true,
                  onConfirm: _confirm,
                  onReject: _reject,
                  onRefresh: _load,
                  emptyText: 'Күтүп жаткан төлөм жок',
                ),
                _PaymentList(
                  payments: _confirmed,
                  isPending: false,
                  onConfirm: _confirm,
                  onReject: _reject,
                  onRefresh: _load,
                  emptyText: 'Тастыкталган төлөм жок',
                ),
              ],
            ),
    );
  }
}

// ─── Payment List ─────────────────────────────────────────────────────────────

class _PaymentList extends StatelessWidget {
  final List<dynamic> payments;
  final bool isPending;
  final void Function(int) onConfirm;
  final void Function(int) onReject;
  final Future<void> Function() onRefresh;
  final String emptyText;

  const _PaymentList({
    required this.payments,
    required this.isPending,
    required this.onConfirm,
    required this.onReject,
    required this.onRefresh,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.payment_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(emptyText,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: payments.length,
        itemBuilder: (_, i) => _PaymentCard(
          payment: payments[i],
          isPending: isPending,
          onConfirm: onConfirm,
          onReject: onReject,
        ),
      ),
    );
  }
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final dynamic payment;
  final bool isPending;
  final void Function(int) onConfirm;
  final void Function(int) onReject;

  const _PaymentCard({
    required this.payment,
    required this.isPending,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final id = payment['id'] as int;
    final orderId = payment['order_id'];
    final amount = (payment['amount'] as num).toStringAsFixed(0);
    final user = payment['user_name'] ?? payment['user_phone'] ?? 'Кардар';
    final phone = payment['user_phone'] as String? ?? '';
    final screenshotUrl = payment['screenshot_url'] as String?;
    final note = payment['note'] as String?;
    final createdAt = (payment['created_at'] as String? ?? '');
    final status = payment['status'] as String? ?? '';

    final statusColor = switch (status) {
      'confirmed' => const Color(0xFF16A34A),
      'rejected'  => const Color(0xFFDC2626),
      _           => const Color(0xFFF59E0B),
    };
    final statusLabel = switch (status) {
      'confirmed' => '✅ Тастыкталды',
      'rejected'  => '❌ Четке кагылды',
      _           => '⏳ Күтүүдө',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Text('Заказ #$orderId',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person_outline, size: 15, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(user + (phone.isNotEmpty ? '  $phone' : ''),
                  style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text('$amount сом',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF16A34A))),
            ]),
            if (createdAt.length >= 16) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(createdAt.replaceAll('T', ' ').substring(0, 16),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(note,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ),
            ],

            // Screenshot
            if (screenshotUrl != null && screenshotUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showScreenshot(context, screenshotUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _ScreenshotImage(
                    url: screenshotUrl,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Скриншотту чоңойтуу үчүн басыңыз',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],

            // Action buttons
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onReject(id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Четке кагуу'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onConfirm(id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Тастыктоо'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            child: Center(
              child: _ScreenshotImage(url: url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Screenshot Image (handles both base64 data URLs and regular http URLs) ───

class _ScreenshotImage extends StatelessWidget {
  final String url;
  final double? height;
  final BoxFit fit;

  const _ScreenshotImage({required this.url, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      // base64 data URL → extract the base64 part after the comma
      final commaIdx = url.indexOf(',');
      if (commaIdx == -1) return _error();
      try {
        final bytes = base64Decode(url.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: fit,
          errorBuilder: (_, _, _) => _error(),
        );
      } catch (_) {
        return _error();
      }
    }
    // Regular http/https URL
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => _error(),
    );
  }

  Widget _error() => Container(
        height: height ?? 80,
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF), size: 28),
            SizedBox(height: 4),
            Text('Скриншот жүктөлбөдү',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          ]),
        ),
      );
}
