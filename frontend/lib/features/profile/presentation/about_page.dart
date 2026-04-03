import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Программа жөнүндө'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo + App name
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'БАТКЕН ЭКСПРЕСС',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Версия 1.0.1',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App description
            _SectionCard(
              title: 'Программа жөнүндө',
              icon: Icons.info_outline,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Баткен Экспресс — Баткен шаарынын жана коңшу аймактарынын тез жеткирүү кызматы.',
                    style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF444444)),
                  ),
                  SizedBox(height: 12),
                  _FeatureRow(icon: Icons.delivery_dining, text: 'Курьер аркылуу тез жеткирүү'),
                  _FeatureRow(icon: Icons.store_outlined, text: 'Ишканалардын менюсунан буйрутма берүү'),
                  _FeatureRow(icon: Icons.route_outlined, text: 'Шаарлар аралык жеткирүү'),
                  _FeatureRow(icon: Icons.location_on_outlined, text: 'Реалдуу убакытта курьердин жайгашуусун көрүү'),
                  _FeatureRow(icon: Icons.account_balance_wallet_outlined, text: 'Ички баланс жана онлайн-төлөм'),
                  _FeatureRow(icon: Icons.headset_mic_outlined, text: 'Колдоо чат кызматы'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // How it works
            _SectionCard(
              title: 'Кантип иштейт?',
              icon: Icons.help_outline,
              child: const Column(
                children: [
                  _StepRow(step: '1', text: 'Колдонуучу каттоодон өтүп, заказ берет'),
                  _StepRow(step: '2', text: 'Тутум жакын курьерди автоматтык тандайт'),
                  _StepRow(step: '3', text: 'Курьер заказды кабыл алып, жолго чыгат'),
                  _StepRow(step: '4', text: 'Колдонуучу картада курьерди реалдуу убакытта көрөт'),
                  _StepRow(step: '5', text: 'Жеткирилгенден кийин баланстан акы алынат'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Developer
            _SectionCard(
              title: 'Иштеп чыгуучу',
              icon: Icons.code,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nurgazy Uson uulu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ContactTile(
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    value: '+996 999 310 893',
                    onTap: () => _launch('https://wa.me/996999310893'),
                  ),
                  _ContactTile(
                    icon: Icons.send_outlined,
                    color: const Color(0xFF2AABEE),
                    label: 'Telegram',
                    value: '@nur93r',
                    onTap: () => _launch('https://t.me/nur93r'),
                  ),
                  _ContactTile(
                    icon: Icons.camera_alt_outlined,
                    color: const Color(0xFFE1306C),
                    label: 'Instagram',
                    value: '@batkendik.mugalim',
                    onTap: () => _launch('https://instagram.com/batkendik.mugalim'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              '© 2024–2025 Баткен Экспресс. Бардык укуктар корголгон.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF555555)))),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String text;

  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF444444))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
