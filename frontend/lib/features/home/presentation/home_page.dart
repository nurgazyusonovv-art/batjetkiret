import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/distance_calculator.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/features/common/widgets/compact_map_preview.dart';
import 'package:frontend/features/home/data/category_model.dart' as models;
import 'package:frontend/features/home/data/enterprise_api.dart';
import 'package:frontend/features/home/data/enterprise_model.dart';
import 'package:frontend/features/home/data/banner_api.dart';
import 'package:frontend/features/home/data/banner_model.dart';
import 'package:frontend/features/home/data/ad_popup_api.dart';
import 'package:frontend/features/home/data/ad_popup_model.dart';
import 'banner_carousel.dart';
import 'ad_popup_overlay.dart';
import 'package:frontend/features/home/presentation/cubit/home_cubit.dart';
import 'package:frontend/features/home/presentation/cubit/order_create_cubit.dart';
import 'package:frontend/features/home/presentation/cubit/order_create_state.dart';
import 'package:frontend/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:frontend/features/home/presentation/order_payment_sheet.dart';
import 'package:frontend/features/orders/presentation/order_detail_page.dart';
import 'package:frontend/features/orders/presentation/order_success_page.dart';
import 'package:frontend/features/profile/data/support_api.dart';
import 'package:frontend/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intercity_order_page.dart';

class HomePage extends StatefulWidget {
  final String token;
  const HomePage({super.key, required this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _pressedCategoryIndex;
  List<models.Category> _filteredCategories = [];
  List<BannerItem> _banners = [];

  @override
  void initState() {
    super.initState();
    _filteredCategories = models.categories;
    _fetchBanners();
    _checkAndShowPopup();
  }

  Future<void> _fetchBanners() async {
    final list = await BannerApi().fetchBanners();
    if (mounted) setState(() => _banners = list);
  }

  Future<void> _checkAndShowPopup() async {
    final popup = await AdPopupApi.fetchCurrent();
    if (popup == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'seen_ad_popup_${popup.id}';
    if (prefs.getBool(seenKey) == true) return;

    await prefs.setBool(seenKey, true);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => AdPopupOverlay(
        popup: popup,
        onClose: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
  }

  Future<void> _acceptOrder(order) async {
    try {
      await context.read<HomeCubit>().acceptOrder(widget.token, order.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _categoryIconFor(dynamic category) {
    // Return an icon for the given category (stub)
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeCubit>().state;
    final profileState = context.watch<ProfileCubit>().state;
    final user = profileState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Listener(
        onPointerDown: (_) {
          // Dismiss keyboard when tapping
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              // Header with logo and location
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'БАТКЕН ЭКСПРЕСС',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    // Show location for regular users, online/offline toggle for couriers
                    if (user != null)
                      if (user.isCourier)
                        // Online/Offline toggle for couriers
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: user.isOnline
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: user.isOnline
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () async {
                              final profileCubit = context.read<ProfileCubit>();
                              final homeCubit = context.read<HomeCubit>();
                              await profileCubit.toggleOnlineStatus(
                                widget.token,
                                !user.isOnline,
                              );
                              // Refresh available orders after status change
                              if (mounted) {
                                homeCubit.refreshAvailableOrders(widget.token);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: user.isOnline
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.isOnline ? 'Онлайнда' : 'Офлайнда',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: user.isOnline
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Categories section for users / Waiting orders list for couriers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    homeState.isCourier ? 'Күтүүдөгү заказдар' : 'Категориялар',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (homeState.isCourier && (user?.balance ?? 0) < 0) ...[
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.block, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Балансыңыз терс. Заказ кабыл алуу үчүн алгач балансыңызды толуктаңыз.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: homeState.isCourier
                    ? homeState.isCourierLoading
                        ? const Center(child: CircularProgressIndicator())
                        : homeState.courierError != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 46,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Text(
                                        homeState.courierError!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppButton.primary(
                                      onPressed: () => context
                                          .read<HomeCubit>()
                                          .loadCourierHomeData(widget.token),
                                      label: 'Кайра жүктөө',
                                    ),
                                  ],
                                ),
                              )
                            : homeState.availableOrders.isEmpty
                                ? Center(
                                    child: Text(
                                      'Азыр күтүүдөгү заказдар жок',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    itemCount: homeState.availableOrders.length,
                                    itemBuilder: (context, index) {
                                      final order = homeState.availableOrders[index];
                                      final isAccepting = homeState.acceptingOrderIds
                                          .contains(order.id);
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primarySoft,
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      _categoryIconFor(
                                                        order.category,
                                                      ),
                                                      size: 20,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    order.categoryName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${(order.estimatedPrice ?? 0).toStringAsFixed(0)} сом',
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '${order.fromAddress} → ${order.toAddress}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (order.description
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                order.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              OrderDetailPage(
                                                                order: order,
                                                                token: widget.token,
                                                                isCourier: homeState
                                                                    .isCourier,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      side: BorderSide(
                                                        color: AppColors.border,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                      ),
                                                    ),
                                                    child: const Text('Деталь'),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: AppButton.primary(
                                                    onPressed: isAccepting
                                                        ? null
                                                        : () => _acceptOrder(order),
                                                    isLoading: isAccepting,
                                                    label: 'Кабыл алуу',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                    : CustomScrollView(
                        slivers: [
                          // ── Реклама карусели ──────────────────────────────
                          if (_banners.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                                child: BannerCarousel(banners: _banners),
                              ),
                            ),

                          // ── Категориялар ──────────────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.15,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final category = _filteredCategories[index];
                                  final cardColor = _categoryColor(index);
                                  final iconBgColor = _categoryIconBg(index);

                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(
                                      milliseconds: 200 + ((index % 8) * 40),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) =>
                                        Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - value) * 14),
                                        child: child,
                                      ),
                                    ),
                                    child: GestureDetector(
                                      onTapDown: (_) => setState(
                                          () => _pressedCategoryIndex = index),
                                      onTapCancel: () => setState(
                                          () => _pressedCategoryIndex = null),
                                      onTapUp: (_) => setState(
                                          () => _pressedCategoryIndex = null),
                                      onTap: () {
                                        if (category.id == 'intercity') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => IntercityOrderPage(
                                                token: widget.token,
                                                userId: user?.id ?? 0,
                                              ),
                                            ),
                                          );
                                        } else {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  OrderCreatePage(
                                                token: widget.token,
                                                selectedCategory: category,
                                                initialFromAddress:
                                                    user?.address ??
                                                    (homeState.selectedLocation !=
                                                            'адрес киргиз'
                                                        ? homeState
                                                            .selectedLocation
                                                        : null),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: AnimatedScale(
                                        scale: _pressedCategoryIndex == index
                                            ? 0.97
                                            : 1.0,
                                        duration:
                                            const Duration(milliseconds: 120),
                                        curve: Curves.easeOut,
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 52,
                                                    height: 52,
                                                    decoration: BoxDecoration(
                                                      color: iconBgColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              13),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        category.icon,
                                                        size: 26,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    category.name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Тандоо үчүн басыңыз',
                                                    style: TextStyle(
                                                      color: Color(0xFFFDF2E8),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topRight:
                                                        Radius.circular(22),
                                                    bottomLeft:
                                                        Radius.circular(22),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.north_east,
                                                  size: 15,
                                                  color: cardColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: _filteredCategories.length,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(int index) {
    const palette = [
      AppColors.accent1,
      AppColors.accent2,
      AppColors.accent3,
      AppColors.accent4,
      AppColors.accent5,
    ];
    return palette[index % palette.length];
  }

  Color _categoryIconBg(int index) {
    const palette = [
      Color(0x55FFF3D1),
      Color(0x55FFE3BF),
      Color(0x55FFD1B0),
      Color(0x55FFC6C6),
      Color(0x55EFAAAA),
    ];
    return palette[index % palette.length];
  }
}


// ── Order creation screen — Multi-step wizard ─────────────────────────────────

class OrderCreatePage extends StatefulWidget {
  final String token;
  final models.Category selectedCategory;
  final String? initialFromAddress;

  const OrderCreatePage({
    super.key,
    required this.token,
    required this.selectedCategory,
    this.initialFromAddress,
  });

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  late final OrderCreateCubit _cubit;

  // Address controllers
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _notesController = TextEditingController();

  // Map coordinates
  LatLng? _selectedFromLocation;
  LatLng? _selectedToLocation;

  // GPS state
  bool _isGettingFromLocation = false;
  bool _isGettingToLocation = false;

  // App settings (fetched from backend)
  AppSettings _appSettings = AppSettings.defaults;

  // Enterprise list
  List<Enterprise>? _enterprises;
  bool _isLoadingEnterprises = false;
  String? _enterpriseError;

  // Enterprise menu
  EnterpriseMenu? _enterpriseMenu;
  bool _isLoadingMenu = false;
  String? _menuError;
  int _menuFetchVersion = 0; // Version counter to discard stale responses

  // Suggestion addresses
  final List<String> _suggestions = [
    'Бишкек, ул. Жибек Жолу, 123',
    'Бишкек, пр. Чуй, 456',
    'Бишкек, ул. Боконбаева, 789',
    'Бишкек, ул. Сатпаева, 321',
    'Бишкек, пр. Манаса, 654',
    'Бишкек, ул. Всемирная, 987',
  ];

  @override
  void initState() {
    super.initState();
    _cubit = OrderCreateCubit();
    if (widget.initialFromAddress != null) {
      _fromAddressController.text = widget.initialFromAddress!;
    }
    // Rebuild when address text changes (for suggestions dropdown)
    _fromAddressController.addListener(() => setState(() {}));
    _toAddressController.addListener(() => setState(() {}));
    _fetchEnterprises();
    _fetchAppSettings();
  }

  @override
  void dispose() {
    _cubit.close();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchAppSettings() async {
    try {
      final settings = await SupportApi().getAppSettings();
      if (!mounted) return;
      setState(() => _appSettings = settings);
    } catch (_) {}
  }

  Future<void> _fetchEnterprises() async {
    setState(() {
      _isLoadingEnterprises = true;
      _enterpriseError = null;
    });
    try {
      final api = EnterpriseApi();
      final list = await api.fetchEnterprises(
        token: widget.token,
        category: widget.selectedCategory.id,
      );
      if (!mounted) return;
      setState(() {
        _enterprises = list;
        _isLoadingEnterprises = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enterpriseError = e.toString();
        _isLoadingEnterprises = false;
      });
    }
  }

  Future<void> _fetchEnterpriseMenu(int enterpriseId) async {
    final version = ++_menuFetchVersion;
    setState(() {
      _isLoadingMenu = true;
      _menuError = null;
    });
    try {
      final api = EnterpriseApi();
      final menu = await api.fetchEnterpriseMenu(
        token: widget.token,
        enterpriseId: enterpriseId,
      );
      if (!mounted || version != _menuFetchVersion) return;
      setState(() {
        _enterpriseMenu = menu;
        _isLoadingMenu = false;
      });
    } catch (e) {
      if (!mounted || version != _menuFetchVersion) return;
      setState(() {
        _menuError = e.toString();
        _isLoadingMenu = false;
      });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goToNextStep({String? overrideFrom, String? overrideTo}) {
    final message = _cubit.goToNextStep(
      fromAddress: overrideFrom ?? _fromAddressController.text,
      toAddress: overrideTo ?? _toAddressController.text,
      fromLocation: _selectedFromLocation,
      toLocation: _selectedToLocation,
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
      );
    }
  }

  void _goToPreviousStep() {
    final shouldPop = _cubit.goToPreviousStep();
    if (shouldPop && mounted) Navigator.of(context).pop();
  }

  void _onEnterpriseSelected(Enterprise ent) {
    // Set enterprise in cubit
    _cubit.selectEnterprise(
      id: ent.id,
      name: ent.name,
      address: ent.address ?? '',
      lat: ent.lat,
      lon: ent.lon,
    );
    // Auto-fill from address from enterprise
    _fromAddressController.text = ent.address ?? '';
    if (ent.lat != null && ent.lon != null) {
      setState(() {
        _selectedFromLocation = LatLng(latitude: ent.lat!, longitude: ent.lon!);
      });
    }
    // Mark loading before step change — avoids "Меню жок" flash
    setState(() {
      _isLoadingMenu = true;
      _menuError = null;
      _enterpriseMenu = null;
    });
    _cubit.goToEnterpriseMenuStep();
    _fetchEnterpriseMenu(ent.id);
  }

  void _onManualEnterprise() {
    _cubit.goToPickupStep();
    _fromAddressController.clear();
    setState(() => _selectedFromLocation = null);
  }

  Future<void> _getMyLocation({required bool isFrom}) async {
    setState(() {
      if (isFrom) { _isGettingFromLocation = true; }
      else { _isGettingToLocation = true; }
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS уруксаты берилген жок'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(latitude: pos.latitude, longitude: pos.longitude);
      final address = await RealGeocoder.getAddressFromCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _selectedFromLocation = loc;
          _fromAddressController.text = address;
        } else {
          _selectedToLocation = loc;
          _toAddressController.text = address;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS катасы: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isFrom) { _isGettingFromLocation = false; }
          else { _isGettingToLocation = false; }
        });
      }
    }
  }

  // ── Order submission ────────────────────────────────────────────────────────

  String _buildDescription() {
    final state = _cubit.state;
    if (!state.isEnterprisePath || _enterpriseMenu == null) {
      return _notesController.text.trim();
    }

    // Build from selected items
    final lines = <String>[];
    for (final cat in _enterpriseMenu!.categories) {
      for (final product in cat.products) {
        final qty = state.selectedItems[product.id] ?? 0;
        if (qty > 0) {
          lines.add('${product.name} x$qty');
        }
      }
    }
    final itemsText = lines.join('\n');
    final notes = _notesController.text.trim();
    return notes.isEmpty ? itemsText : '$itemsText\n\n$notes';
  }

  double _buildItemsTotal() {
    if (_enterpriseMenu == null) return 0;
    double total = 0;
    for (final cat in _enterpriseMenu!.categories) {
      for (final product in cat.products) {
        final qty = _cubit.state.selectedItems[product.id] ?? 0;
        total += product.price * qty;
      }
    }
    return total;
  }

  Future<void> _createOrder() async {
    final description = _buildDescription();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказдын сыпаттамасын жазыңыз'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      final itemsTotal = _buildItemsTotal();
      final enterpriseId = _cubit.state.enterpriseId;
      final orderData = await _cubit.createOrder(
        token: widget.token,
        category: widget.selectedCategory.id,
        fromAddress: _fromAddressController.text,
        toAddress: _toAddressController.text,
        description: description,
        fromLocation: _selectedFromLocation,
        toLocation: _selectedToLocation,
        enterpriseId: enterpriseId,
        itemsTotal: itemsTotal > 0 ? itemsTotal : null,
      );
      if (!mounted) return;
      context.read<OrdersCubit>().loadOrders(widget.token);

      if (enterpriseId != null) {
        final orderId = orderData['id'] as int?;
        final amount = (orderData['items_total'] as num?)?.toDouble() ?? itemsTotal;
        if (orderId != null) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => OrderPaymentSheet(
              token: widget.token,
              orderId: orderId,
              enterpriseId: enterpriseId,
              amount: amount,
            ),
          );
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }

      final orderId = orderData['id'] as int?;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessPage(orderId: orderId ?? 0),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _filteredSuggestions(String query) {
    if (query.isEmpty) return _suggestions;
    return _suggestions
        .where((a) => a.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  String _appBarTitle(OrderCreateState state) {
    switch (state.currentStep) {
      case OrderCreateStep.enterpriseSelection:
        return 'Ишкана тандаңыз';
      case OrderCreateStep.enterpriseMenu:
        return state.enterpriseName ?? 'Меню';
      case OrderCreateStep.pickupLocation:
        return 'Жөнөтүүнүн адресси';
      case OrderCreateStep.deliveryLocation:
        return 'Жеткирүүнүн адресси';
      case OrderCreateStep.description:
        return 'Заказды тастыктоо';
    }
  }

  // ── Step indicator ──────────────────────────────────────────────────────────

  int _stepIndex(OrderCreateStep step, bool isEnterprisePath) {
    if (isEnterprisePath) {
      switch (step) {
        case OrderCreateStep.enterpriseMenu:
          return 1;
        case OrderCreateStep.deliveryLocation:
          return 2;
        case OrderCreateStep.description:
          return 3;
        default:
          return 0;
      }
    } else {
      switch (step) {
        case OrderCreateStep.pickupLocation:
          return 1;
        case OrderCreateStep.deliveryLocation:
          return 2;
        case OrderCreateStep.description:
          return 3;
        default:
          return 0;
      }
    }
  }

  Widget _buildStepIndicator(OrderCreateState state) {
    if (state.currentStep == OrderCreateStep.enterpriseSelection) {
      return const SizedBox.shrink();
    }
    final idx = _stepIndex(state.currentStep, state.isEnterprisePath);
    final labels = state.isEnterprisePath
        ? ['Меню', 'Жеткирүү', 'Заказ']
        : ['Жөнөтүү', 'Жеткирүү', 'Заказ'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final stepNum = i + 1;
          final isActive = stepNum == idx;
          final isCompleted = stepNum < idx;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : (isCompleted ? Colors.green : Colors.grey[300]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '$stepNum',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? AppColors.primary : Colors.grey[600],
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: isCompleted ? Colors.green : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Address field with suggestions ──────────────────────────────────────────

  Widget _buildAddressField({
    required TextEditingController controller,
    required String hint,
    required String label,
  }) {
    // Note: controller listeners are added in initState for setState-driven suggestions
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: controller,
          hintText: hint,
          prefixIcon: const Icon(Icons.location_on),
        ),
        if (controller.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _filteredSuggestions(controller.text)
                  .take(4)
                  .map((addr) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                        title: Text(addr, style: const TextStyle(fontSize: 13)),
                        onTap: () => setState(() => controller.text = addr),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMapSection({
    required LatLng? location,
    required String mapLabel,
    required void Function(LatLng, String?) onChanged,
    Color locationColor = Colors.green,
  }) {
    return Column(
      children: [
        CompactMapPreview(
          initialLocation: location,
          label: mapLabel,
          onLocationChanged: (loc, addr) => onChanged(loc, addr),
        ),
        if (location != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: locationColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: locationColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location, color: locationColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Координата: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Step bodies ─────────────────────────────────────────────────────────────

  Widget _buildEnterpriseSelectionBody() {
    if (_isLoadingEnterprises) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_enterpriseError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_enterpriseError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              AppButton.primary(label: 'Кайра жүктөө', onPressed: _fetchEnterprises),
            ],
          ),
        ),
      );
    }

    final enterprises = _enterprises ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.selectedCategory.icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(widget.selectedCategory.name,
                    style: const TextStyle(color: AppColors.primary, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (enterprises.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.store_outlined, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Бул категорияда ишканалар жок',
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Ишкана тандаңыз',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: enterprises.length,
              itemBuilder: (_, i) {
                final ent = enterprises[i];
                return GestureDetector(
                  onTap: () => _onEnterpriseSelected(ent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.store, color: AppColors.primary, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          ent.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (ent.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            ent.address!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Manual / other enterprise button
          AppButton.secondary(
            label: enterprises.isEmpty ? 'Адрести кол менен киргизүү' : 'Башка ишкана',
            onPressed: _onManualEnterprise,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEnterpriseMenuBody(OrderCreateState state) {
    if (_isLoadingMenu) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_menuError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_menuError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              AppButton.primary(
                label: 'Кайра жүктөө',
                onPressed: () => _fetchEnterpriseMenu(_cubit.state.enterpriseId!),
              ),
            ],
          ),
        ),
      );
    }

    if (_enterpriseMenu == null || !_enterpriseMenu!.hasProducts) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Меню азырынча жок',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 24),
              AppButton.secondary(
                label: 'Башка ишкана',
                onPressed: _onManualEnterprise,
              ),
            ],
          ),
        ),
      );
    }

    final menu = _enterpriseMenu!;
    final ent = menu.enterprise;
    final itemsTotal = _buildItemsTotal();

    return Column(
      children: [
        // Enterprise info bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.store, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ent.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (ent.address != null)
                      Text(ent.address!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (ent.phone != null)
                Icon(Icons.phone, color: Colors.grey[400], size: 18),
            ],
          ),
        ),

        // Product grid — 2 columns
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: menu.categories.length,
            itemBuilder: (_, catIdx) {
              final cat = menu.categories[catIdx];
              // Build pairs for 2-column grid
              final products = cat.products;
              final rows = <Widget>[];
              for (int i = 0; i < products.length; i += 2) {
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildProductCard(products[i], state)),
                      const SizedBox(width: 10),
                      if (i + 1 < products.length)
                        Expanded(child: _buildProductCard(products[i + 1], state))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
                rows.add(const SizedBox(height: 10));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      cat.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ...rows,
                ],
              );
            },
          ),
        ),

        // Bottom bar: total + continue
        if (state.totalItemCount > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showSelectedItemsSheet(state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${state.totalItemCount} товар',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            Text(
                              '${itemsTotal.toStringAsFixed(0)} сом',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    label: 'Улантуу →',
                    onPressed: _goToNextStep,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showSelectedItemsSheet(OrderCreateState state) {
    final menu = _enterpriseMenu;
    if (menu == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selectedItems = _cubit.state.selectedItems;
          int count = 0;
          final rows = <Widget>[];
          for (final cat in menu.categories) {
            for (final product in cat.products) {
              final qty = selectedItems[product.id] ?? 0;
              if (qty > 0) {
                count += qty;
                rows.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Minus
                        GestureDetector(
                          onTap: () {
                            _cubit.removeItem(product.id);
                            setSheetState(() {});
                            setState(() {});
                            if (_cubit.state.totalItemCount == 0) {
                              Navigator.of(ctx).pop();
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 8),
                        // Plus
                        GestureDetector(
                          onTap: () {
                            _cubit.addItem(product.id);
                            setSheetState(() {});
                            setState(() {});
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(product.name,
                              style: const TextStyle(fontSize: 14)),
                        ),
                        Text(
                          '${(product.price * qty).toStringAsFixed(0)} сом',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Тандалган товарлар',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const Spacer(),
                    Text('$count даана',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Эч нерсе тандалган жок',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(child: Column(children: rows)),
                  ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Жалпы:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Text(
                      '${_buildItemsTotal().toStringAsFixed(0)} сом',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.primary(
                    label: 'Улантуу →',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _goToNextStep();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPickupLocationBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Жөнөтүүнүн адресси',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Товар кайдан алынат?',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildAddressField(
            controller: _fromAddressController,
            hint: 'Мисал: ул. Жибек Жолу, 123',
            label: 'Жөнөтүүнүн адресси',
          ),
          const SizedBox(height: 10),
          _buildMyLocationButton(isFrom: true),
          const SizedBox(height: 16),
          _buildMapSection(
            location: _selectedFromLocation,
            mapLabel: 'Картадан тандаңыз',
            onChanged: (loc, addr) {
              setState(() {
                _selectedFromLocation = loc;
                if (addr != null) { _fromAddressController.text = addr; }
              });
            },
            locationColor: Colors.green,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDeliveryLocationBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Жеткирүүнүн адресси',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Кайда жеткирип берели?',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildAddressField(
            controller: _toAddressController,
            hint: 'Мисал: пр. Чуй, 456',
            label: 'Жеткирүүнүн адресси',
          ),
          const SizedBox(height: 10),
          _buildMyLocationButton(isFrom: false),
          const SizedBox(height: 16),
          _buildMapSection(
            location: _selectedToLocation,
            mapLabel: 'Картадан тандаңыз',
            onChanged: (loc, addr) {
              setState(() {
                _selectedToLocation = loc;
                if (addr != null) { _toAddressController.text = addr; }
              });
            },
            locationColor: Colors.blue,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMyLocationButton({required bool isFrom}) {
    final isLoading = isFrom ? _isGettingFromLocation : _isGettingToLocation;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _getMyLocation(isFrom: isFrom),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
        label: Text(
          isLoading ? 'Аныкталуудa...' : 'Менин учурдагы ордум',
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDescriptionBody(OrderCreateState state) {
    final distKm = state.calculatedDistance;
    final price = distKm != null
        ? (_appSettings.deliveryBasePrice + distKm * _appSettings.deliveryPricePerKm)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                _buildAddressRow(
                  icon: Icons.location_on,
                  label: 'Кайдан',
                  value: _fromAddressController.text.isNotEmpty
                      ? _fromAddressController.text
                      : '—',
                  color: Colors.green.shade700,
                ),
                Divider(color: Colors.green.shade200, height: 16),
                _buildAddressRow(
                  icon: Icons.flag,
                  label: 'Кайда',
                  value: _toAddressController.text.isNotEmpty
                      ? _toAddressController.text
                      : '—',
                  color: Colors.blue.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Distance + price
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Аралык', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        distKm != null ? '${distKm.toStringAsFixed(1)} км' : 'Эсептелүүдө...',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Болжолдуу баа',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '${price.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Service fee notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Заказ жаратылганда ${_appSettings.userServiceFee.toStringAsFixed(0)} сом сервис акы алынат',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Enterprise path: selected items list
          if (state.isEnterprisePath && _enterpriseMenu != null) ...[
            Text('Тандалган товарлар',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (final cat in _enterpriseMenu!.categories)
                    for (final product in cat.products)
                      if ((state.selectedItems[product.id] ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${product.name} × ${state.selectedItems[product.id]}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${(product.price * (state.selectedItems[product.id] ?? 0)).toStringAsFixed(0)} сом',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Жалпы:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '${_buildItemsTotal().toStringAsFixed(0)} сом',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Кошумча маалымат (милдеттүү эмес)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppTextField(
              controller: _notesController,
              maxLines: 3,
              hintText: 'Жеткирүүчүгө эскертүү, унутпачу...',
            ),
          ]

          // Manual path: description required
          else ...[
            Text(
              'Сыпаттама (милдеттүү)',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _notesController,
              maxLines: 5,
              hintText: 'Эмне жеткирип берүү керек? Деталдуу жаз...',
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom navigation bar ───────────────────────────────────────────────────

  Widget? _buildBottomBar(OrderCreateState state) {
    // Enterprise selection: no bar (cards navigate directly; manual button at bottom of scroll)
    if (state.currentStep == OrderCreateStep.enterpriseSelection) return null;

    // Enterprise menu: custom bottom bar rendered inside the body
    if (state.currentStep == OrderCreateStep.enterpriseMenu) return null;

    final isLast = state.currentStep == OrderCreateStep.description;
    final profileUser = context.read<ProfileCubit>().state.user;
    final isNegativeBalance = isLast && (profileUser?.balance ?? 0) < 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isNegativeBalance)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFEE2E2),
            child: const Row(
              children: [
                Icon(Icons.block, color: Color(0xFFDC2626), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Балансыңыз терс. Заказ берүү үчүн алгач балансыңызды толуктаңыз.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  onPressed: _goToPreviousStep,
                  label: '← Артка',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  onPressed: (state.isLoading || isNegativeBalance)
                      ? null
                      : (isLast ? _createOrder : _goToNextStep),
                  isLoading: state.isLoading,
                  label: isLast ? 'Заказ түзүү' : 'Улантуу →',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<OrderCreateCubit, OrderCreateState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(_appBarTitle(state)),
              leading: BackButton(onPressed: _goToPreviousStep),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: _buildStepIndicator(state),
              ),
            ),
            body: switch (state.currentStep) {
              OrderCreateStep.enterpriseSelection => _buildEnterpriseSelectionBody(),
              OrderCreateStep.enterpriseMenu => _buildEnterpriseMenuBody(state),
              OrderCreateStep.pickupLocation => _buildPickupLocationBody(),
              OrderCreateStep.deliveryLocation => _buildDeliveryLocationBody(),
              OrderCreateStep.description => _buildDescriptionBody(state),
            },
            bottomNavigationBar: _buildBottomBar(state),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(EnterpriseMenuProduct product, OrderCreateState state) {
    final qty = state.selectedItems[product.id] ?? 0;
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: qty > 0 ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0 ? AppColors.primary : AppColors.border,
          width: qty > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image or placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: hasImage
                ? _buildProductImage(product.imageUrl!, height: 120)
                : _productImagePlaceholder(),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.description != null && product.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.description!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${product.price.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (qty == 0)
                  GestureDetector(
                    onTap: () => _cubit.addItem(product.id),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '+ Кошуу',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _cubit.removeItem(product.id),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove, size: 17),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _cubit.addItem(product.id),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, size: 17, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl, {double height = 120}) {
    if (imageUrl.startsWith('data:')) {
      // base64 data URL — extract the base64 part after the comma
      final commaIdx = imageUrl.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(imageUrl.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _productImagePlaceholder(),
          );
        } catch (_) {}
      }
      return _productImagePlaceholder();
    }
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _productImagePlaceholder(),
    );
  }

  Widget _productImagePlaceholder() {
    return Container(
      height: 120,
      color: AppColors.primarySoft,
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 48, color: AppColors.primary),
      ),
    );
  }

}
