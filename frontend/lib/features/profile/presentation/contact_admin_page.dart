// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../data/support_api.dart';
import 'support_chat_page.dart';

class ContactAdminPage extends StatefulWidget {
  final String token;
  final int userId;
  final Future<int> Function() startChatFn;

  const ContactAdminPage({
    super.key,
    required this.token,
    required this.userId,
    required this.startChatFn,
  });

  @override
  State<ContactAdminPage> createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage> {
  final _api = SupportApi();
  ContactInfo? _info;
  bool _loading = true;
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await _api.getContactInfo();
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _info = const ContactInfo(telegram: '', whatsapp: ''); _loading = false; });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Колдонмо ачылбай жатат')),
        );
      }
    }
  }

  Future<void> _openChat() async {
    setState(() => _chatLoading = true);
    try {
      final chatId = await widget.startChatFn();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatPage(
            token: widget.token,
            chatId: chatId,
            title: 'Администратор',
            myUserId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTelegram = (_info?.telegram ?? '').isNotEmpty;
    final hasWhatsApp = (_info?.whatsapp ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Администраторго жазуу',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Байланыш жолун тандаңыз',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // In-app chat
                _ContactTile(
                  icon: Icons.chat_bubble_outline,
                  iconBg: const Color(0xFFE0E7FF),
                  iconColor: const Color(0xFF4F46E5),
                  title: 'Колдонмо ичинде чат',
                  subtitle: 'Администратор менен түз байланышуу',
                  loading: _chatLoading,
                  onTap: _openChat,
                ),

                if (hasTelegram) ...[
                  const SizedBox(height: 10),
                  _ContactTile(
                    icon: Icons.telegram,
                    iconBg: const Color(0xFFE0F4FF),
                    iconColor: const Color(0xFF2AABEE),
                    title: 'Telegram',
                    subtitle: '@${_info!.telegram}',
                    onTap: () => _openUrl('https://t.me/${_info!.telegram}'),
                  ),
                ],

                if (hasWhatsApp) ...[
                  const SizedBox(height: 10),
                  _ContactTile(
                    icon: Icons.chat,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF25D366),
                    title: 'WhatsApp',
                    subtitle: '+${_info!.whatsapp}',
                    onTap: () => _openUrl('https://wa.me/${_info!.whatsapp}'),
                  ),
                ],

                if (!hasTelegram && !hasWhatsApp) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Администратор байланыш маалыматтарын азырынча коюган жок',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  const _ContactTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                      )
                    : Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
