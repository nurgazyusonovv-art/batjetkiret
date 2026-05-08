import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum AppRole { user, courier, enterprise }

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key, required this.onRoleSelected});

  final void Function(AppRole role) onRoleSelected;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage>
    with SingleTickerProviderStateMixin {
  AppRole? _selected;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    widget.onRoleSelected(_selected!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ── Header ────────────────────────────────────────────────
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.waving_hand_rounded,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ролуңузду тандаңыз',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Кийинки экраныңыз ушул тандоого жараша ачылат.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Role cards ────────────────────────────────────────────
                _RoleCard(
                  role: AppRole.user,
                  selected: _selected,
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  bgColor: AppColors.primarySoft,
                  title: 'Жөнөкөй колдонуучу',
                  subtitle: 'Заказ бер, жеткирүү байка,\nчат аркылуу байланыш.',
                  onTap: () => setState(() => _selected = AppRole.user),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  role: AppRole.courier,
                  selected: _selected,
                  icon: Icons.delivery_dining_rounded,
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  title: 'Курьер',
                  subtitle: 'Заказдарды кабыл ал,\nжеткир жана кирешеңди арттыр.',
                  onTap: () => setState(() => _selected = AppRole.courier),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  role: AppRole.enterprise,
                  selected: _selected,
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                  title: 'Ишканы башкаруу',
                  subtitle: 'Менюну, заказдарды жана\nкирешени башкар.',
                  onTap: () => setState(() => _selected = AppRole.enterprise),
                ),

                const Spacer(),

                // ── Continue button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _selected != null ? 1.0 : 0.4,
                    child: ElevatedButton(
                      onPressed: _selected != null ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Уланта бер',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single role card ─────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppRole role;
  final AppRole? selected;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  bool get _isSelected => selected == role;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSelected ? color : const Color(0xFFE5E7EB),
            width: _isSelected ? 2 : 1.5,
          ),
          boxShadow: _isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isSelected ? color : bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  size: 26, color: _isSelected ? Colors.white : color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isSelected ? color : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: _isSelected ? color : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: _isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
