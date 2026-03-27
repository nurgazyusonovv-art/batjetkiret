import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  static const _autoSlideInterval = Duration(seconds: 5);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;
  Timer? _autoSlideTimer;

  late final AnimationController _fadeCtrl;

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.bolt_rounded,
      accent: Color(0xFF6C63FF),
      title: 'Заказды\nбат кабыл ал',
      subtitle: 'Жакынкы заказдарды бир тийүү\nменен кабыл алыңыз',
    ),
    _Slide(
      icon: Icons.account_balance_wallet_rounded,
      accent: Color(0xFF00B894),
      title: 'Кирешеңди\nкөзөмөлдө',
      subtitle: 'Баланс, төлөм жана тарых\nтолук колдоруңузда',
    ),
    _Slide(
      icon: Icons.chat_bubble_rounded,
      accent: Color(0xFFFF7675),
      title: 'Колдоо ар\nдайым жанында',
      subtitle: 'Кардар менен чат аркылуу\nылдам байланышыңыз',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeCtrl.forward();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted || _isCompleting || !_pageController.hasClients) return;
      if (_currentPage >= _slides.length - 1) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _complete() async {
    if (_isCompleting) return;
    _autoSlideTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _isCompleting = true);
    await widget.onFinish();
    if (mounted) setState(() => _isCompleting = false);
  }

  void _next() {
    if (_currentPage >= _slides.length - 1) {
      _complete();
      return;
    }
    HapticFeedback.selectionClick();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _startAutoSlide();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded,
                            color: AppColors.primary, size: 22.r),
                        SizedBox(width: 4.w),
                        Text(
                          'BATKEN',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _isCompleting ? null : _complete,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 6.h),
                      ),
                      child: Text('Өткөрүү',
                          style: TextStyle(fontSize: 13.sp)),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                    _startAutoSlide();
                  },
                  itemBuilder: (_, i) =>
                      _SlideView(slide: _slides[i], isActive: i == _currentPage),
                ),
              ),

              // Bottom controls
              Padding(
                padding:
                    EdgeInsets.fromLTRB(28.w, 0, 28.w, 32.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          width: active ? 28.w : 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: active
                                ? slide.accent
                                : const Color(0xFFE0E0E0),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 28.h),

                    // CTA button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: slide.accent,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: slide.accent.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.r),
                          onTap: _isCompleting ? null : _next,
                          child: Center(
                            child: _isCompleting
                                ? SizedBox(
                                    width: 22.r,
                                    height: 22.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isLast ? 'Баштоо' : 'Кийинки',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        isLast
                                            ? Icons.rocket_launch_rounded
                                            : Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20.r,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
}

class _SlideView extends StatefulWidget {
  const _SlideView({required this.slide, required this.isActive});

  final _Slide slide;
  final bool isActive;

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    if (widget.isActive) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_SlideView old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            children: [
              SizedBox(height: 16.h),
              // Illustration
              ScaleTransition(
                scale: _scale,
                child: _IllustrationBox(slide: widget.slide),
              ),
              SizedBox(height: 40.h),
              // Title
              Text(
                widget.slide.title,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A2E),
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 14.h),
              // Subtitle
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.slide.subtitle,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: const Color(0xFF7B7B93),
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationBox extends StatelessWidget {
  const _IllustrationBox({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240.h,
      decoration: BoxDecoration(
        color: slide.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30.r,
            right: -30.r,
            child: Container(
              width: 140.r,
              height: 140.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.accent.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -20.r,
            left: -20.r,
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.accent.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Main icon
          Center(
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                color: slide.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(slide.icon, size: 52.r, color: slide.accent),
            ),
          ),
          // Small accent dots
          Positioned(
            top: 28.r,
            left: 28.r,
            child: _Dot(color: slide.accent, size: 10.r),
          ),
          Positioned(
            bottom: 32.r,
            right: 36.r,
            child: _Dot(color: slide.accent, size: 7.r),
          ),
          Positioned(
            top: 48.r,
            right: 56.r,
            child: _Dot(color: slide.accent, size: 5.r),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}
