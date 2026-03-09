import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _autoSlideInterval = Duration(seconds: 4);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;
  Timer? _autoSlideTimer;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.route_rounded,
      sideIcon: Icons.pin_drop_rounded,
      title: 'Заказды бат кабыл ал',
      description:
          'Жакынкы заказдарды картадан көрүп, бир тийүү менен кабыл алыңыз.',
      colors: [Color(0xFFFFC857), Color(0xFFFF8A3D)],
      imageAsset: 'web/icons/Icon-512.png',
    ),
    _OnboardingSlide(
      icon: Icons.account_balance_wallet_rounded,
      sideIcon: Icons.trending_up_rounded,
      title: 'Кирешеңиз дайыма көзөмөлдө',
      description:
          'Баланс, төлөм жана тарых бөлүмдөрү аркылуу акча агымын так көзөмөлдөңүз.',
      colors: [Color(0xFFFF9B54), Color(0xFFE85D04)],
      imageAsset: 'web/icons/Icon-maskable-512.png',
    ),
    _OnboardingSlide(
      icon: Icons.support_agent_rounded,
      sideIcon: Icons.notifications_active_rounded,
      title: 'Колдоо ар дайым жанында',
      description:
          'Чат жана билдирмелер аркылуу кардар менен ылдам байланыш түзүңүз.',
      colors: [Color(0xFFFF7B54), Color(0xFFD62828)],
      imageAsset: 'web/icons/Icon-maskable-192.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted ||
          _isCompleting ||
          _currentPage >= _slides.length - 1 ||
          !_pageController.hasClients) {
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    });
  }

  void _restartAutoSlide() {
    _startAutoSlide();
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  Future<void> _complete() async {
    if (_isCompleting) return;
    _stopAutoSlide();
    HapticFeedback.lightImpact();
    setState(() {
      _isCompleting = true;
    });
    await widget.onFinish();
    if (!mounted) return;
    setState(() {
      _isCompleting = false;
    });
  }

  void _nextPage() {
    if (_currentPage >= _slides.length - 1) {
      _complete();
      return;
    }
    HapticFeedback.selectionClick();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    _restartAutoSlide();
  }

  void _previousPage() {
    if (_currentPage <= 0) return;
    HapticFeedback.selectionClick();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    _restartAutoSlide();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 72),
                  Expanded(
                    child: Center(
                      child: Text(
                        'BatJetkiret',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextButton(
                      onPressed: _isCompleting ? null : _complete,
                      child: const Text('Өткөрүү'),
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _stopAutoSlide();
                  }
                  if (notification is ScrollEndNotification) {
                    _restartAutoSlide();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final isActive = index == _currentPage;
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0.96,
                                  end: isActive ? 1 : 0.97,
                                ),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutBack,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: _OnboardingHero(
                                  slide: slide,
                                  isActive: isActive,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                transitionBuilder: (child, animation) {
                                  final offset = Tween<Offset>(
                                    begin: const Offset(0.1, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return SlideTransition(
                                    position: offset,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  slide.title,
                                  key: ValueKey<String>('title_$index'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: Text(
                                  slide.description,
                                  key: ValueKey<String>('description_$index'),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.35,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Footer with controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwipeProgressIndicator(
                    pageController: _pageController,
                    totalPages: _slides.length,
                    onBack: _currentPage > 0 ? _previousPage : null,
                    onForward: _nextPage,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(_slides.length, (index) {
                            final active = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.only(right: 6),
                              width: active ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: active
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            );
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: FilledButton(
                          onPressed: _isCompleting ? null : _nextPage,
                          child: _isCompleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLast ? 'Баштоо' : 'Кийинки'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.sideIcon,
    required this.title,
    required this.description,
    required this.colors,
    required this.imageAsset,
  });

  final IconData icon;
  final IconData sideIcon;
  final String title;
  final String description;
  final List<Color> colors;
  final String imageAsset;
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.slide, required this.isActive});

  final _OnboardingSlide slide;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(slide.imageAsset, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 18,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: isActive ? 1 : 0.9,
              child: _BadgeIcon(icon: slide.sideIcon),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 18,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isActive ? 1 : 0.7,
              child: _BadgeIcon(icon: slide.icon),
            ),
          ),
          Center(
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 350),
              turns: isActive ? 0 : -0.015,
              child: Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(slide.icon, size: 74, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

class _SwipeProgressIndicator extends StatelessWidget {
  const _SwipeProgressIndicator({
    required this.pageController,
    required this.totalPages,
    required this.onBack,
    required this.onForward,
  });

  final PageController pageController;
  final int totalPages;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Артка',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: pageController,
            builder: (context, _) {
              final rawPage = pageController.hasClients
                  ? (pageController.page ?? 0)
                  : 0;
              final maxPage = totalPages > 1
                  ? (totalPages - 1).toDouble()
                  : 1.0;
              final progress = (rawPage / maxPage).clamp(0.0, 1.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Swipe прогресс: ${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Алдыга',
          onPressed: onForward,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    );
  }
}
