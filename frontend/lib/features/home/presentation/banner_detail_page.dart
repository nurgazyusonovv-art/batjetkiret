import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/banner_model.dart';
import '../../../core/theme/app_colors.dart';

class BannerDetailPage extends StatelessWidget {
  final BannerItem banner;

  const BannerDetailPage({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageData != null && banner.imageData!.isNotEmpty;
    final hasLink = banner.linkUrl != null && banner.linkUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Hero image ──────────────────────────────────────────────
          Expanded(
            child: hasImage
                ? _BannerFullImage(imageData: banner.imageData!)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFFE53935)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.campaign, color: Colors.white54, size: 80),
                    ),
                  ),
          ),

          // ── Info card ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                if (banner.title?.isNotEmpty ?? false) ...[
                  Text(
                    banner.title!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Subtitle
                if (banner.subtitle?.isNotEmpty ?? false) ...[
                  Text(
                    banner.subtitle!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF555555),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!(banner.title?.isNotEmpty ?? false) &&
                    !(banner.subtitle?.isNotEmpty ?? false))
                  const SizedBox(height: 8),

                // Link button (only if url provided)
                if (hasLink)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openLink(banner.linkUrl!),
                      icon: const Icon(Icons.open_in_new, size: 20),
                      label: const Text(
                        'Шилтемеге өтүү',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _BannerFullImage extends StatelessWidget {
  final String imageData;
  const _BannerFullImage({required this.imageData});

  @override
  Widget build(BuildContext context) {
    if (imageData.startsWith('data:')) {
      final commaIdx = imageData.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(imageData.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          );
        } catch (_) {}
      }
    }
    return Image.network(
      imageData,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white30, size: 60),
        ),
      ),
    );
  }
}
