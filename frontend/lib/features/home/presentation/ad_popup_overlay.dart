import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/ad_popup_model.dart';
import '../../../core/theme/app_colors.dart';

class AdPopupOverlay extends StatefulWidget {
  final AdPopupItem popup;
  final VoidCallback onClose;

  const AdPopupOverlay({super.key, required this.popup, required this.onClose});

  @override
  State<AdPopupOverlay> createState() => _AdPopupOverlayState();
}

class _AdPopupOverlayState extends State<AdPopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.popup;
    final hasImage = p.imageData != null && p.imageData!.isNotEmpty;
    final hasLink = p.linkUrl != null && p.linkUrl!.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // prevent close when tapping card
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Image ───────────────────────────────────
                          if (hasImage)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              child: SizedBox(
                                height: 200,
                                child: _buildImage(p.imageData!),
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              child: Container(
                                height: 120,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      Color(0xFFE53935)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.campaign,
                                      color: Colors.white54, size: 56),
                                ),
                              ),
                            ),

                          // ── Content ─────────────────────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(22, 20, 22, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ЖАРНАМА',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Title
                                if (p.title?.isNotEmpty ?? false) ...[
                                  Text(
                                    p.title!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1A1A),
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Subtitle
                                if (p.subtitle?.isNotEmpty ?? false) ...[
                                  Text(
                                    p.subtitle!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ] else
                                  const SizedBox(height: 18),

                                // Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _close,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF888888),
                                          side: const BorderSide(
                                              color: Color(0xFFDDDDDD)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                        ),
                                        child: const Text('Жабуу',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    if (hasLink) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _openLink(p.linkUrl!),
                                          icon: const Icon(Icons.open_in_new,
                                              size: 16),
                                          label: const Text('Шилтемеге өтүү',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 13),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageData) {
    if (imageData.startsWith('data:')) {
      final idx = imageData.indexOf(',');
      if (idx != -1) {
        try {
          final bytes = base64Decode(imageData.substring(idx + 1));
          return Image.memory(bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity);
        } catch (_) {}
      }
    }
    return Image.network(imageData,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ));
  }
}
