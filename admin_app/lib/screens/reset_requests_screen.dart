import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart' show showLocalNotification, AppEntry;

class ResetRequestsScreen extends StatefulWidget {
  const ResetRequestsScreen({super.key});

  @override
  State<ResetRequestsScreen> createState() => _ResetRequestsScreenState();
}

class _ResetRequestsScreenState extends State<ResetRequestsScreen>
    with WidgetsBindingObserver {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  Set<int> _knownIds = {};
  bool _fcmOk = false;
  bool _fcmChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
    _checkFcm();
    FirebaseMessaging.onMessage.listen((msg) {
      _load(silent: true);
      // Foreground'да FCM келсе локал notification көрсөтөбүз
      final title = msg.notification?.title ?? msg.data['title'] ?? '🔑 Жаңы өтүнүч';
      final body = msg.notification?.body ?? msg.data['body'] ?? '';
      showLocalNotification(title, body);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _load());
  }

  Future<void> _checkFcm() async {
    setState(() { _fcmChecking = true; });
    try {
      final token = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 10));
      if (token != null && mounted) {
        setState(() { _fcmOk = true; _fcmChecking = false; });
        AuthService.uploadFcmToken();
        return;
      }
    } catch (_) {}
    if (mounted) setState(() { _fcmOk = false; _fcmChecking = false; });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
      if (!_fcmOk) _checkFcm();
    }
  }

  void _startPolling() {
    // 30 секунд сайын текшеребиз — FCM иштебесе да notification келет
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollForNew();
    });
  }

  Future<void> _pollForNew() async {
    try {
      final data = await ApiService.getResetRequests();
      final newIds = data.map<int>((r) => r['id'] as int).toSet();

      if (_knownIds.isNotEmpty) {
        final added = newIds.difference(_knownIds);
        for (final id in added) {
          final req = data.firstWhere((r) => r['id'] == id);
          final user = req['user'] ?? {};
          final name = user['name'] ?? 'Колдонуучу';
          final phone = user['phone'] ?? '';
          final code = req['code'] ?? '';
          await showLocalNotification(
            '🔑 Жаңы сырсөз өтүнүчү',
            '$name ($phone) — код: $code',
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
      final data = await ApiService.getResetRequests();
      _knownIds = data.map<int>((r) => r['id'] as int).toSet();
      if (mounted) setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  Future<void> _dismiss(int id) async {
    try {
      await ApiService.dismiss(id);
      _knownIds.remove(id);
      _load(silent: true);
    } catch (_) {}
  }

  String _buildSmsUrl(String phone, String name, String code) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('996')
        ? '+$digits'
        : '+996${digits.replaceFirst(RegExp(r'^0'), '')}';
    final msg = Uri.encodeComponent(
      'Саламатсызбы, $name! Сиздин сырсөздү баштан коюу коду: $code. Кодду колдонмого киргизиңиз.',
    );
    return 'sms:$normalized?body=$msg';
  }

  String _buildWhatsAppUrl(String phone, String name, String code) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('996')
        ? digits
        : '996${digits.replaceFirst(RegExp(r'^0'), '')}';
    final msg = Uri.encodeComponent(
      'Саламатсызбы, $name!\n\nСиздин сырсөздү баштан коюу коду:\n\n*$code*\n\nКодду колдонмого киргизиңиз. Код 24 саат ичинде жарактуу.',
    );
    return 'https://wa.me/$normalized?text=$msg';
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    // AppEntry'ге кайтабыз — ал login экранын көрсөтөт
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppEntry()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        toolbarHeight: 48,
        title: Row(
          children: [
            const Text('Сырсөз өтүнүчтөрү',
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
          GestureDetector(
            onTap: _checkFcm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: _fcmChecking
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _fcmOk ? Icons.notifications_active : Icons.notifications_off,
                      color: _fcmOk ? Colors.greenAccent : Colors.white54,
                      size: 18,
                    ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load, padding: EdgeInsets.zero),
          IconButton(icon: const Icon(Icons.logout, size: 18), onPressed: _logout, padding: EdgeInsets.zero),
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
                      child: Column(
                        children: [
                          Text(_error!,
                              style:
                                  const TextStyle(color: Color(0xFFDC2626))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load, child: const Text('Кайра')),
                        ],
                      ),
                    ),
                  ])
                : _requests.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('Азырынча өтүнүч жок',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 16)),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) {
                          final r = _requests[i];
                          final user = r['user'] ?? {};
                          final phone = user['phone'] ?? '';
                          final name = user['name'] ?? 'Колдонуучу';
                          final code = r['code'] ?? '';
                          return _RequestCard(
                            data: r,
                            onWhatsApp: () {
                              launchUrl(
                                Uri.parse(_buildWhatsAppUrl(phone, name, code)),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            onSms: () {
                              launchUrl(
                                Uri.parse(_buildSmsUrl(phone, name, code)),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            onDismiss: () => _dismiss(r['id']),
                          );
                        },
                      ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final dynamic data;
  final VoidCallback onWhatsApp;
  final VoidCallback onSms;
  final VoidCallback onDismiss;

  const _RequestCard(
      {required this.data,
      required this.onWhatsApp,
      required this.onSms,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final user = data['user'] ?? {};
    final name = user['name'] ?? 'Колдонуучу';
    final phone = user['phone'] ?? '';
    final code = data['code'] ?? '';
    final createdAt = (data['created_at'] ?? '').toString();

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
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color(0xFFDC2626),
                      letterSpacing: 3,
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
            if (createdAt.length >= 16) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(createdAt.replaceAll('T', ' ').substring(0, 16),
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onWhatsApp,
                  icon: const Text('📱', style: TextStyle(fontSize: 14)),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSms,
                  icon: const Icon(Icons.sms, size: 16),
                  label: const Text('SMS', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('✕', style: TextStyle(fontSize: 13)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
