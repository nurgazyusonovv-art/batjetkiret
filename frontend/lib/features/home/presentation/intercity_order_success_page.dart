// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/data/user_api.dart';
import '../../profile/presentation/contact_admin_page.dart';

class IntercityOrderSuccessPage extends StatefulWidget {
  final String token;
  final int userId;
  final String fromAddress;
  final String toCity;
  final double price;

  const IntercityOrderSuccessPage({
    super.key,
    required this.token,
    required this.userId,
    required this.fromAddress,
    required this.toCity,
    required this.price,
  });

  @override
  State<IntercityOrderSuccessPage> createState() => _IntercityOrderSuccessPageState();
}

class _IntercityOrderSuccessPageState extends State<IntercityOrderSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAdminContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactAdminPage(
          token: widget.token,
          userId: widget.userId,
          startChatFn: () => UserApi().startSupportChat(widget.token),
        ),
      ),
    );
  }

  void _goHome() {
    // Pop until we reach the home page
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Success icon ──────────────────────────────────────────
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF16A34A),
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Title ─────────────────────────────────────────────────
                const Text(
                  'Заказ ийгиликтүү түзүлдү!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ── Pickup time notice ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Color(0xFF0284C7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Биздин курьер',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Кечки саат 16:00 гө чейин барып алып кетет',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Даяр болуп туруңуз. Суроолор болсо, администратор менен байланышыңыз.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Order summary ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _summaryRow(
                        Icons.location_on,
                        'Кайдан',
                        widget.fromAddress.isNotEmpty ? widget.fromAddress : '—',
                        Colors.green.shade700,
                      ),
                      const Divider(height: 16),
                      _summaryRow(
                        Icons.flag,
                        'Кайда',
                        widget.toCity,
                        Colors.blue.shade700,
                      ),
                      const Divider(height: 16),
                      _summaryRow(
                        Icons.monetization_on,
                        'Жеткирүү баасы',
                        '${widget.price.toStringAsFixed(0)} сом',
                        AppColors.primary,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Buttons ───────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openAdminContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.support_agent, color: Colors.white, size: 22),
                    label: const Text(
                      'Администраторго кайрылуу',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _goHome,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Башкы бетке кайтуу',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
