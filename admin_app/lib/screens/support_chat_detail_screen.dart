import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

class SupportChatDetailScreen extends StatefulWidget {
  const SupportChatDetailScreen({
    super.key,
    required this.chatId,
    required this.userName,
    required this.userPhone,
    required this.token,
  });

  final int chatId;
  final String userName;
  final String userPhone;
  final String token;

  @override
  State<SupportChatDetailScreen> createState() =>
      _SupportChatDetailScreenState();
}

class _SupportChatDetailScreenState extends State<SupportChatDetailScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _connected = false;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _socket?.sink.close();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadMessages();
    _parseMyId();
    await _connectSocket();
    _markRead();
  }

  void _parseMyId() {
    // JWT payload'дан user id алабыз
    try {
      final parts = widget.token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _myUserId = int.tryParse(data['sub'].toString());
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getChatMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectSocket() async {
    _sub?.cancel();
    await _socket?.sink.close();

    try {
      final url = ApiService.chatWebSocketUrl(widget.chatId, widget.token);
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _socket = channel;
      _sub = channel.stream.listen(
        _onEvent,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
        cancelOnError: true,
      );
      if (mounted) setState(() => _connected = true);
      _send({'event': 'ping'});
    } catch (_) {
      _onDisconnect();
    }
  }

  void _onDisconnect() {
    if (!mounted) return;
    setState(() => _connected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectSocket);
  }

  void _onEvent(dynamic raw) {
    Map<String, dynamic>? data;
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      return;
    }
    if (data == null || !mounted) return;

    final event = data['event']?.toString();
    if (event == 'new_message') {
      final payload = data['message'];
      if (payload is! Map) return;
      final msg = Map<String, dynamic>.from(payload);
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
        if (idx >= 0) {
          _messages = [..._messages.take(idx), msg, ..._messages.skip(idx + 1)];
        } else {
          _messages = [..._messages, msg];
        }
      });
      if (_nearBottom()) _scrollToBottom();
      final senderId = (msg['sender_id'] as num?)?.toInt();
      if (senderId != _myUserId) _markRead();
    }
  }

  void _send(Map<String, dynamic> data) {
    try {
      _socket?.sink.add(jsonEncode(data));
    } catch (_) {
      _onDisconnect();
    }
  }

  void _markRead() {
    _send({'event': 'mark_read'});
    ApiService.markChatRead(widget.chatId).catchError((_) {});
  }

  bool _nearBottom() {
    if (!_scroll.hasClients) return true;
    return (_scroll.position.maxScrollExtent - _scroll.position.pixels) < 120;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      if (_connected) {
        _send({'event': 'send_message', 'text': text});
      } else {
        await ApiService.sendSupportMessage(widget.chatId, text);
        await _loadMessages();
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жиберилбеди')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMine(Map<String, dynamic> msg) {
    return (msg['sender_id'] as num?)?.toInt() == _myUserId;
  }

  String _formatTime(String raw) {
    final utc = raw.endsWith('Z') ? raw : '${raw}Z';
    final dt = DateTime.tryParse(utc);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(widget.userPhone,
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _connected ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: _connected ? Colors.greenAccent : Colors.white54,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Азырынча билдирүү жок',
                            style: TextStyle(color: Color(0xFF9CA3AF))),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final mine = _isMine(msg);
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.76,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFDC2626)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: mine
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg['text'] as String? ?? '',
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(
                                        msg['created_at'] as String? ?? ''),
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white70
                                          : const Color(0xFF9CA3AF),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Жооп жазыңыз...',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
