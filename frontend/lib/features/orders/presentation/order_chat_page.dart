import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/theme/app_colors.dart';
import '../data/chat_message_model.dart';
import '../data/order_api.dart';

class OrderChatPage extends StatefulWidget {
  const OrderChatPage({
    super.key,
    required this.token,
    required this.orderId,
    required this.counterpartyName,
    required this.counterpartyId,
  });

  final String token;
  final int orderId;
  final String counterpartyName;
  final int? counterpartyId;

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage>
    with WidgetsBindingObserver {
  final OrderApi _orderApi = OrderApi();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;

  int? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSocketConnected = false;
  String? _error;
  List<ChatMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAsRead();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatId = await _orderApi.getOrderChatId(
        token: widget.token,
        orderId: widget.orderId,
      );
      if (!mounted) return;

      _chatId = chatId;
      await _loadMessages(autoscroll: true);
      await _connectSocket();
      await _markAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectSocket() async {
    final chatId = _chatId;
    if (chatId == null || !mounted) return;

    _socketSubscription?.cancel();
    await _socket?.sink.close();

    try {
      final wsUri = _orderApi.buildChatWebSocketUri(
        chatId: chatId,
        token: widget.token,
      );
      final channel = WebSocketChannel.connect(wsUri);

      _socket = channel;
      _socketSubscription = channel.stream.listen(
        _handleSocketEvent,
        onError: (_) => _handleSocketClosed(),
        onDone: _handleSocketClosed,
        cancelOnError: true,
      );

      if (!mounted) return;
      setState(() {
        _isSocketConnected = true;
      });

      _sendSocketEvent({'event': 'ping'});
    } catch (_) {
      _handleSocketClosed();
    }
  }

  void _handleSocketClosed() {
    if (!mounted) return;

    setState(() {
      _isSocketConnected = false;
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _connectSocket();
    });
  }

  void _handleSocketEvent(dynamic raw) {
    Map<String, dynamic>? data;

    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } else if (raw is Map) {
        data = raw.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return;
    }

    if (data == null || !mounted) return;

    final event = data['event']?.toString();
    if (event == 'new_message') {
      final payload = data['message'];
      if (payload is! Map) return;

      final normalized = payload.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final incoming = ChatMessage.fromJson(normalized);

      setState(() {
        final existingIndex = _messages.indexWhere((m) => m.id == incoming.id);
        if (existingIndex >= 0) {
          _messages = [
            ..._messages.take(existingIndex),
            incoming,
            ..._messages.skip(existingIndex + 1),
          ];
        } else {
          _messages = [..._messages, incoming];
        }
      });

      if (_shouldStickToBottom()) {
        _scrollToBottom();
      }

      final isMine = _isMine(incoming);
      if (!isMine) {
        _markAsRead();
      }

      return;
    }

    if (event == 'read_update') {
      final readerId = (data['reader_id'] as num?)?.toInt();
      final lastReadId = (data['last_read_message_id'] as num?)?.toInt();
      if (readerId == null || lastReadId == null) return;

      setState(() {
        _messages = _messages.map((message) {
          final shouldMarkRead =
              message.id <= lastReadId && message.senderId != readerId;
          if (!shouldMarkRead || message.isRead) {
            return message;
          }
          return message.copyWith(isRead: true);
        }).toList();
      });
      return;
    }
  }

  void _sendSocketEvent(Map<String, dynamic> data) {
    try {
      _socket?.sink.add(jsonEncode(data));
    } catch (_) {
      _handleSocketClosed();
    }
  }

  Future<void> _loadMessages({bool autoscroll = false}) async {
    final chatId = _chatId;
    if (chatId == null) return;

    try {
      final messages = await _orderApi.getChatMessages(
        token: widget.token,
        chatId: chatId,
      );

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });

      if (autoscroll || _shouldStickToBottom()) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _markAsRead() async {
    final chatId = _chatId;
    if (chatId == null) return;

    _sendSocketEvent({'event': 'mark_read'});
    await _orderApi.markChatMessagesAsRead(token: widget.token, chatId: chatId);
  }

  bool _shouldStickToBottom() {
    if (!_scrollController.hasClients) return true;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    return (max - current) < 120;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isMine(ChatMessage message) {
    if (widget.counterpartyId == null) return false;
    return message.senderId != widget.counterpartyId;
  }

  Future<void> _sendMessage() async {
    final chatId = _chatId;
    if (chatId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      if (_isSocketConnected) {
        _sendSocketEvent({'event': 'send_message', 'text': text});
      } else {
        await _orderApi.sendChatMessage(
          token: widget.token,
          chatId: chatId,
          text: text,
        );
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatTime(String raw) {
    final utc = raw.endsWith('Z') ? raw : '${raw}Z';
    final parsed = DateTime.tryParse(utc);
    if (parsed == null) return '';

    final local = parsed.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.counterpartyName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'Заказ #${widget.orderId}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _isSocketConnected
                        ? AppColors.accent4
                        : AppColors.accent5,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSocketConnected ? 'Live' : 'Offline',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent5.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.accent5, fontSize: 12),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Азырынча билдирүү жок',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = _isMine(message);

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.76,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isMine ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMine
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: isMine
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(
                                      color: isMine
                                          ? Colors.white.withAlpha(190)
                                          : AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      message.isRead
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 12,
                                      color: message.isRead
                                          ? AppColors.accent4
                                          : Colors.white.withAlpha(190),
                                    ),
                                  ],
                                ],
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
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Билдирүү жазыңыз...',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
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
