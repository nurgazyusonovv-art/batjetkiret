import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/banner_model.dart';
import '../data/banner_api.dart';
import '../../../core/theme/app_colors.dart';
import 'banner_detail_page.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;

  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;
  final _api = BannerApi();
  final _trackedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    if (widget.banners.length > 1) _startTimer();
    // Track first banner view on load
    if (widget.banners.isNotEmpty) _trackView(widget.banners[0].id);
  }

  void _trackView(int bannerId) {
    if (_trackedIds.contains(bannerId)) return;
    _trackedIds.add(bannerId);
    _api.trackView(bannerId);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(BannerItem b) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BannerDetailPage(banner: b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _trackView(widget.banners[i].id);
            },
            itemBuilder: (_, i) {
              final b = widget.banners[i];
              return GestureDetector(
                onTap: () => _onTap(b),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _BannerCard(banner: b),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.imageData != null && banner.imageData!.isNotEmpty;
    final hasText = (banner.title?.isNotEmpty ?? false) || (banner.subtitle?.isNotEmpty ?? false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image or gradient
          if (hasImage)
            _buildImage(banner.imageData!)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

          // Dark overlay for text readability
          if (hasText && hasImage)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Text overlay
          if (hasText)
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banner.title?.isNotEmpty ?? false)
                    Text(
                      banner.title!,
                      style: TextStyle(
                        color: hasImage ? Colors.white : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        shadows: hasImage
                            ? [const Shadow(color: Colors.black45, blurRadius: 4)]
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (banner.subtitle?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 3),
                    Text(
                      banner.subtitle!,
                      style: TextStyle(
                        color: hasImage ? Colors.white70 : Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        shadows: hasImage
                            ? [const Shadow(color: Colors.black45, blurRadius: 3)]
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

          // Link arrow indicator
          if (banner.linkUrl?.isNotEmpty ?? false)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.north_east, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageData) {
    if (imageData.startsWith('data:')) {
      final commaIdx = imageData.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(imageData.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Image.network(imageData, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradient());
  }

  Widget _gradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}
