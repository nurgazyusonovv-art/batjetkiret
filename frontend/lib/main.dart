import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'core/config.dart';
import 'core/storage/hive_service.dart';
import 'core/notifications/notification_overlay.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';
import 'features/home/presentation/home_page.dart';
import 'features/home/presentation/cubit/home_cubit.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/orders/presentation/cubit/orders_cubit.dart';
import 'features/orders/presentation/my_orders_page.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.initialize();
  runApp(const BatJetkiretApp());
}

class BatJetkiretApp extends StatelessWidget {
  const BatJetkiretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()..bootstrap()),
        BlocProvider(create: (_) => OrdersCubit()),
        BlocProvider(create: (_) => HomeCubit()),
        BlocProvider(create: (_) => ProfileCubit()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) => previous.token != current.token,
        listener: (context, state) {
          context.read<OrdersCubit>().hydrateOnAuth(state.token);
          context.read<HomeCubit>().hydrateOnAuth(state.token);
          context.read<ProfileCubit>().hydrateOnAuth(state.token);
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            return NotificationOverlay(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'BatJetkiret',
                theme: AppTheme.light,
                home: _AppStartFlow(authState: authState),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppStartFlow extends StatefulWidget {
  const _AppStartFlow({required this.authState});

  final AuthState authState;

  @override
  State<_AppStartFlow> createState() => _AppStartFlowState();
}

class _AppStartFlowState extends State<_AppStartFlow> {
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _minSplashDuration = Duration(seconds: 2);

  bool _isSplashDone = false;
  bool? _isOnboardingSeen;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingSeenKey) ?? false;

    await Future<void>.delayed(_minSplashDuration);
    if (!mounted) return;

    setState(() {
      _isOnboardingSeen = seen;
      _isSplashDone = true;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (!mounted) return;

    setState(() {
      _isOnboardingSeen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSplashDone ||
        _isOnboardingSeen == null ||
        !widget.authState.isInitialized) {
      return const SplashScreen();
    }

    if (_isOnboardingSeen == false) {
      return OnboardingPage(onFinish: _finishOnboarding);
    }

    if (widget.authState.token != null && widget.authState.token!.isNotEmpty) {
      return MainNavigation(token: widget.authState.token!);
    }

    return const AuthPage();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.token});

  final String token;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late final List<Widget> _pages;
  Timer? _autoRefreshTimer;
  bool _isAppInForeground = true;
  bool _isRefreshing = false;
  int _consecutiveRefreshErrors = 0;

  // Refresh intervals loaded from AppConfig (configurable via environment)
  Duration get _homeActiveInterval => AppConfig.homeActiveInterval;
  Duration get _homeIdleInterval => AppConfig.homeIdleInterval;
  Duration get _ordersActiveInterval => AppConfig.ordersActiveInterval;
  Duration get _ordersIdleInterval => AppConfig.ordersIdleInterval;
  Duration get _profileInterval => AppConfig.profileInterval;
  Duration get _maxBackoffInterval => AppConfig.maxBackoffInterval;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [ 
      HomePage(token: widget.token),
      MyOrdersPage(token: widget.token),
      ProfilePage(
        token: widget.token,
        onLogout: () => context.read<AuthCubit>().logout(),
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshForTab(_currentIndex);
      _scheduleNextAutoRefresh();
    });
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _refreshForTab(_currentIndex);
      _scheduleNextAutoRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _refreshForTab(_currentIndex);
      _scheduleNextAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _autoRefreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Duration _nextIntervalForCurrentTab() {
    if (_currentIndex == 0) {
      final homeState = context.read<HomeCubit>().state;
      return homeState.availableOrders.isNotEmpty
          ? _homeActiveInterval
          : _homeIdleInterval;
    }

    if (_currentIndex == 1) {
      final ordersState = context.read<OrdersCubit>().state;
      final hasActiveOrders = ordersState.orders.any(
        (order) =>
            order.status != 'completed' &&
            order.status != 'cancelled' &&
            order.status != 'delivered',
      );

      return hasActiveOrders ? _ordersActiveInterval : _ordersIdleInterval;
    }

    return _profileInterval;
  }

  Duration _withBackoff(Duration base) {
    if (_consecutiveRefreshErrors <= 0) return base;

    final factor =
        1 << (_consecutiveRefreshErrors > 4 ? 4 : _consecutiveRefreshErrors);
    final multiplied = Duration(seconds: base.inSeconds * factor);
    if (multiplied > _maxBackoffInterval) {
      return _maxBackoffInterval;
    }
    return multiplied;
  }

  void _scheduleNextAutoRefresh() {
    _autoRefreshTimer?.cancel();

    if (!mounted || !_isAppInForeground || widget.token.isEmpty) {
      return;
    }

    final nextInterval = _withBackoff(_nextIntervalForCurrentTab());
    _autoRefreshTimer = Timer(nextInterval, () async {
      if (!mounted || !_isAppInForeground) return;
      await _refreshForTab(_currentIndex, silent: true);
      _scheduleNextAutoRefresh();
    });
  }

  Future<void> _refreshForTab(int tabIndex, {bool silent = false}) async {
    if (!mounted || widget.token.isEmpty || _isRefreshing) return;

    final homeCubit = context.read<HomeCubit>();
    final ordersCubit = context.read<OrdersCubit>();
    final profileCubit = context.read<ProfileCubit>();

    _isRefreshing = true;
    try {
      if (tabIndex == 0) {
        await homeCubit.loadCourierHomeData(widget.token, silent: silent);
        final hasError = homeCubit.state.courierError != null;
        _consecutiveRefreshErrors = hasError
            ? _consecutiveRefreshErrors + 1
            : 0;
        return;
      }

      if (tabIndex == 1) {
        await ordersCubit.loadOrders(widget.token, silent: silent);
        final hasError = ordersCubit.state.error != null;
        _consecutiveRefreshErrors = hasError
            ? _consecutiveRefreshErrors + 1
            : 0;
        return;
      }

      if (tabIndex == 2) {
        await profileCubit.loadUser(widget.token, silent: silent);
        if (profileCubit.state.user?.isCourier == true) {
          await profileCubit.loadCourierStats(widget.token, silent: true);
        }
        final hasError = profileCubit.state.error != null;
        _consecutiveRefreshErrors = hasError
            ? _consecutiveRefreshErrors + 1
            : 0;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final movingForward = _currentIndex >= _previousIndex;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final beginOffset = movingForward
              ? const Offset(0.08, 0)
              : const Offset(-0.08, 0);
          final slide = Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
          });
          _refreshForTab(index);
          _scheduleNextAutoRefresh();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Башкы бет'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Заказдар',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
