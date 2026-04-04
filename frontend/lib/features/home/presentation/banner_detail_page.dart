import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/banner_model.dart';
import '../../../core/theme/app_colors.dart';

class BannerDetailPage extends StatefulWidget {
  final BannerItem banner;

  const BannerDetailPage({super.key, required this.banner});

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banner;
    final hasImage = b.imageData != null && b.imageData!.isNotEmpty;
    final hasLink = b.linkUrl != null && b.linkUrl!.isNotEmpty;
    final hasTitle = b.title?.isNotEmpty ?? false;
    final hasSubtitle = b.subtitle?.isNotEmpty ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // ── Full-screen background image ──────────────────────────
            Positioned.fill(
              child: hasImage
                  ? _buildImage(b.imageData!)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A1A2E), AppColors.primary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.campaign,
                            color: Colors.white24, size: 100),
                      ),
                    ),
            ),

            // ── Gradient overlay bottom ───────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 0.65, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom content card ───────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ad badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ЖАРНАМА',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title
                          if (hasTitle) ...[
                            Text(
                              b.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 2))
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Subtitle
                          if (hasSubtitle) ...[
                            Text(
                              b.subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ] else
                            const SizedBox(height: 24),

                          // Link button
                          if (hasLink)
                            _LinkButton(url: b.linkUrl!)
                          else
                            // Close button if no link
                            _CloseButton(onTap: () => Navigator.of(context).pop()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
              fit: BoxFit.cover, width: double.infinity, height: double.infinity);
        } catch (_) {}
      }
    }
    return Image.network(
      imageData,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 72),
        ),
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final String url;
  const _LinkButton({required this.url});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    final uri = Uri.tryParse(widget.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _open,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D0D0D),
          disabledBackgroundColor: Colors.white60,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.black54))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Шилтемеге өтүү',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Жабуу',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
