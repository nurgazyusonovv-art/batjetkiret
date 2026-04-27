import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../main.dart' show showLocalNotification;

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> with WidgetsBindingObserver {
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
      _load(silent: true);
      final ch = msg.data['channel_id'] ?? '';
      if (ch == 'topup_requests') {
        final title = msg.data['title'] ?? '💳 Жаңы топап өтүнүчү';
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
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollForNew());
  }

  Future<void> _pollForNew() async {
    try {
      final data = await ApiService.getTopUpRequests();
      final newIds = data.map<int>((r) => r['id'] as int).toSet();
      if (_knownIds.isNotEmpty) {
        final added = newIds.difference(_knownIds);
        for (final id in added) {
          final req = data.firstWhere((r) => r['id'] == id);
          final name = req['user_name'] ?? 'Колдонуучу';
          final amount = req['amount'] ?? 0;
          await showLocalNotification(
            '💳 Жаңы топап өтүнүчү',
            '$name — ${amount.toStringAsFixed(0)} сом',
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
      final data = await ApiService.getTopUpRequests();
      _knownIds = data.map<int>((r) => r['id'] as int).toSet();
      if (mounted) setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  Future<void> _viewScreenshot(int id) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ScreenshotDialog(requestId: id),
    );
  }

  Future<void> _approve(int id, String name, double amount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Тастыктоо'),
        content: Text('$name — ${amount.toStringAsFixed(0)} сом\nТастыктайсызбы?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Ооба', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.approveTopUp(id);
      _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Топап тастыкталды'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ката чыкты'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(int id) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Четке кагуу себеби'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(hintText: 'Себебин жазыңыз...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Жок')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Четке как', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    try {
      await ApiService.rejectTopUp(id, note);
      _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Четке кагылды')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ката чыкты'), backgroundColor: Colors.red),
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
            const Text('Топап өтүнүчтөрү',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (_requests.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_requests.length}',
                  style: const TextStyle(
                      color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load, padding: EdgeInsets.zero),
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
                        Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Кайра')),
                      ]),
                    ),
                  ])
                : _requests.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('Азырынча топап өтүнүчү жок',
                              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16)),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) {
                          final r = _requests[i];
                          return _TopUpCard(
                            data: r,
                            onApprove: () => _approve(
                              r['id'],
                              r['user_name'] ?? 'Колдонуучу',
                              (r['amount'] as num).toDouble(),
                            ),
                            onReject: () => _reject(r['id']),
                            onScreenshot: r['has_screenshot'] == true
                                ? () => _viewScreenshot(r['id'])
                                : null,
                          );
                        },
                      ),
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  final dynamic data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onScreenshot;

  const _TopUpCard({required this.data, required this.onApprove, required this.onReject, this.onScreenshot});

  @override
  Widget build(BuildContext context) {
    final name = data['user_name'] ?? 'Колдонуучу';
    final phone = data['user_phone'] ?? '';
    final uniqueId = data['unique_id'] ?? '';
    final amount = (data['amount'] as num).toDouble();
    final balance = (data['user_balance'] as num?)?.toDouble() ?? 0;
    final createdAt = (data['created_at'] ?? '').toString();
    final hasScreenshot = data['has_screenshot'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    '${amount.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.phone, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(color: Color(0xFF6B7280))),
            ]),
            if (uniqueId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.badge, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(uniqueId, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                const SizedBox(width: 8),
                Text('Баланс: ${balance.toStringAsFixed(0)} сом',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ]),
            ],
            if (createdAt.length >= 16) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(createdAt.replaceAll('T', ' ').substring(0, 16),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                if (hasScreenshot) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.image, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 2),
                  const Text('скриншот бар',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ]),
            ],
            const SizedBox(height: 12),
            if (onScreenshot != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onScreenshot,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('Скриншотту көрүү', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotDialog extends StatefulWidget {
  final int requestId;
  const _ScreenshotDialog({required this.requestId});

  @override
  State<_ScreenshotDialog> createState() => _ScreenshotDialogState();
}

class _ScreenshotDialogState extends State<_ScreenshotDialog> {
  String? _url;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final url = await ApiService.getTopUpScreenshot(widget.requestId);
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Скриншот жүктөлбөдү'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: _loading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)))
                : _error != null
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: _url!.startsWith('data:')
                            ? Image.memory(
                                _decodeBase64(_url!),
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, e, st) => const Center(
                                  child: Text('Сүрөт жүктөлбөдү',
                                      style: TextStyle(color: Colors.white70)),
                                ),
                              )
                            : Image.network(
                                _url!,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) => progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(color: Colors.white)),
                                errorBuilder: (ctx, e, st) => const Center(
                                  child: Text('Сүрөт жүктөлбөдү',
                                      style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                      ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Uint8List _decodeBase64(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final b64 = dataUrl.substring(comma + 1);
    return base64Decode(b64);
  }
}
