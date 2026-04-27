import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../main.dart' show showLocalNotification;
import 'support_chat_detail_screen.dart';

class SupportChatsScreen extends StatefulWidget {
  const SupportChatsScreen({super.key});

  @override
  State<SupportChatsScreen> createState() => _SupportChatsScreenState();
}

class _SupportChatsScreenState extends State<SupportChatsScreen>
    with WidgetsBindingObserver {
  List<dynamic> _chats = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
    FirebaseMessaging.onMessage.listen((msg) {
      final ch = msg.data['channel_id'] ?? msg.data['type'] ?? '';
      if (ch == 'support_chat' || ch == 'SUPPORT') {
        _load(silent: true);
        final title = msg.data['title'] ?? '💬 Колдоо чаты';
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
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getSupportChats();
      final unread = data.fold<int>(
        0, (sum, c) => sum + ((c['unread_count'] as num?)?.toInt() ?? 0));
      if (mounted) {
        setState(() {
          _chats = data;
          _totalUnread = unread;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Маалымат жүктөлбөдү'; _loading = false; });
    }
  }

  Future<void> _openChat(dynamic chat) async {
    final token = await AuthService.getToken() ?? '';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatDetailScreen(
          chatId: (chat['chat_id'] as num).toInt(),
          userName: chat['user_name'] ?? 'Колдонуучу',
          userPhone: chat['user_phone'] ?? '',
          token: token,
        ),
      ),
    );
    _load(silent: true);
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
            const Text('Колдоо чаттары',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (_totalUnread > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_totalUnread',
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
                            style: const TextStyle(color: Color(0xFFDC2626))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Кайра')),
                      ]),
                    ),
                  ])
                : _chats.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text('Азырынча колдоо чаттары жок',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 16)),
                        ),
                      ])
                    : ListView.separated(
                        itemCount: _chats.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) {
                          final c = _chats[i];
                          final unread =
                              (c['unread_count'] as num?)?.toInt() ?? 0;
                          final lastMsg = c['last_message'] as String?;
                          final lastAt = (c['last_message_at'] ?? '') as String;
                          return ListTile(
                            tileColor: Colors.white,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFDC2626),
                              child: Text(
                                (c['user_name'] as String? ?? '?')
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(
                              c['user_name'] ?? 'Колдонуучу',
                              style: TextStyle(
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: lastMsg != null
                                ? Text(
                                    lastMsg,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unread > 0
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF9CA3AF),
                                      fontSize: 13,
                                    ),
                                  )
                                : const Text('Билдирүү жок',
                                    style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 13)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (lastAt.length >= 16)
                                  Text(
                                    lastAt
                                        .replaceAll('T', ' ')
                                        .substring(11, 16),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                                if (unread > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _openChat(c),
                          );
                        },
                      ),
      ),
    );
  }
}
