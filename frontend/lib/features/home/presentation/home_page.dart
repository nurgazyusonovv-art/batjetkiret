import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../orders/data/order_model.dart';
import '../../orders/presentation/order_detail_page.dart';
import '../../orders/presentation/cubit/orders_cubit.dart';
import '../../profile/presentation/cubit/profile_cubit.dart';
import '../../common/widgets/compact_map_preview.dart';
import 'cubit/home_cubit.dart';
import 'cubit/order_create_cubit.dart';
import 'cubit/order_create_state.dart';
import '../data/category_model.dart' as models;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.token});

  final String token;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  int? _pressedCategoryIndex;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showLocationBottomSheet() {
    final user = context.read<ProfileCubit>().state.user;
    final currentLocation =
        user?.address ?? context.read<HomeCubit>().state.selectedLocation;
    _locationController.text = currentLocation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Адресс киргизиңиз',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _locationController,
                  hintText: 'Мисалы: Бишкек, Чуй 122',
                  prefixIcon: const Icon(Icons.location_on),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        label: 'Отмена',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        onPressed: () async {
                          if (_locationController.text.trim().isNotEmpty) {
                            final newAddress = _locationController.text.trim();
                            final homeCubit = this.context.read<HomeCubit>();
                            final profileCubit = this.context
                                .read<ProfileCubit>();
                            final nav = Navigator.of(context);

                            // Update location in HomeCubit for immediate UI update
                            await homeCubit.updateLocation(newAddress);

                            // Save to database via ProfileCubit
                            try {
                              await profileCubit.updateProfile(
                                widget.token,
                                address: newAddress,
                              );
                            } catch (e) {
                              // Silent fail - address saved locally at least
                            }

                            if (!mounted) return;
                            nav.pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Адресс киргизиңиз'),
                              ),
                            );
                          }
                        },
                        label: 'Сактоо',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<models.Category> get _filteredCategories {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return models.categories;
    }
    return models.categories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();
  }

  IconData _categoryIconFor(String categoryIdOrName) {
    final normalized = categoryIdOrName.trim().toLowerCase();
    for (final category in models.categories) {
      if (category.id.toLowerCase() == normalized ||
          category.name.toLowerCase() == normalized) {
        return category.icon;
      }
    }
    return Icons.category;
  }

  Future<void> _acceptOrder(Order order) async {
    try {
      await context.read<HomeCubit>().acceptOrder(widget.token, order.id);
      if (!mounted) return;

      // Menin ordersaryn obnovla
      context.read<OrdersCubit>().loadOrders(widget.token);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ кабыл алынды')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
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
                    const Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          size: 28,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'BATJETKIRET',
                          style: TextStyle(
                            fontSize: 18,
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
                              await context
                                  .read<ProfileCubit>()
                                  .toggleOnlineStatus(
                                    widget.token,
                                    !user.isOnline,
                                  );
                              // Refresh available orders after status change
                              if (mounted) {
                                context
                                    .read<HomeCubit>()
                                    .refreshAvailableOrders(widget.token);
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
                      else
                        // Location for regular users
                        Flexible(
                          child: GestureDetector(
                            onTap: _showLocationBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      user.address ??
                                          homeState.selectedLocation,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.expand_more,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AppTextField(
                  controller: _searchController,
                  hintText: 'Издее (тамак-аш, товарлар...)',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 24),
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
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.92,
                            ),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = _filteredCategories[index];
                          final cardColor = _categoryColor(index);
                          final iconBgColor = _categoryIconBg(index);

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 230 + ((index % 8) * 45),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 18),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTapDown: (_) {
                                setState(() {
                                  _pressedCategoryIndex = index;
                                });
                              },
                              onTapCancel: () {
                                setState(() {
                                  _pressedCategoryIndex = null;
                                });
                              },
                              onTapUp: (_) {
                                setState(() {
                                  _pressedCategoryIndex = null;
                                });
                              },
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => OrderCreatePage(
                                      token: widget.token,
                                      selectedCategory: category,
                                      initialFromAddress:
                                          user?.address ??
                                          (homeState.selectedLocation !=
                                                  'адрес киргиз'
                                              ? homeState.selectedLocation
                                              : null),
                                    ),
                                  ),
                                );
                              },
                              child: AnimatedScale(
                                scale: _pressedCategoryIndex == index
                                    ? 0.97
                                    : 1.0,
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: Stack(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 68,
                                                height: 68,
                                                decoration: BoxDecoration(
                                                  color: iconBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    category.icon,
                                                    size: 32,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                category.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Тандоо үчүн басыңыз',
                                                style: TextStyle(
                                                  color: Color(0xFFFDF2E8),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(26),
                                            bottomLeft: Radius.circular(26),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.north_east,
                                          size: 18,
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
                      ),
              ),
              SizedBox(height: 16),
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

// Order creation screen - Multi-step wizard
class OrderCreatePage extends StatefulWidget {
  const OrderCreatePage({
    super.key,
    required this.token,
    required this.selectedCategory,
    this.initialFromAddress,
  });

  final String token;
  final models.Category selectedCategory;
  final String? initialFromAddress;

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  late final OrderCreateCubit _orderCreateCubit;
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _descriptionController = TextEditingController();
  LatLng? _selectedFromLocation;
  LatLng? _selectedToLocation;

  // Common address suggestions
  final List<String> _addressSuggestions = [
    'Бишкек, ул. Жибек Жолу, 123',
    'Бишкек, пр. Чуй, 456',
    'Бишкек, ул. Боконбаева, 789',
    'Бишкек, ул. Сатпаева, 321',
    'Бишкек, пр. Манаса, 654',
    'Бишкек, ул. Всемирная, 987',
  ];

  List<String> _getFilteredSuggestions(String query) {
    if (query.isEmpty) return _addressSuggestions;
    return _addressSuggestions
        .where((addr) => addr.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _orderCreateCubit = OrderCreateCubit();
    if (widget.initialFromAddress != null) {
      _fromAddressController.text = widget.initialFromAddress!;
    }
  }

  @override
  void dispose() {
    _orderCreateCubit.close();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final message = _orderCreateCubit.goToNextStep(
      fromAddress: _fromAddressController.text,
      toAddress: _toAddressController.text,
      fromLocation: _selectedFromLocation,
      toLocation: _selectedToLocation,
    );

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _goToPreviousStep() {
    final shouldPop = _orderCreateCubit.goToPreviousStep();
    if (shouldPop) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createOrder() async {
    try {
      await _orderCreateCubit.createOrder(
        token: widget.token,
        category: widget.selectedCategory.id,
        fromAddress: _fromAddressController.text,
        toAddress: _toAddressController.text,
        description: _descriptionController.text,
        fromLocation: _selectedFromLocation,
        toLocation: _selectedToLocation,
      );

      if (!mounted) return;

      // Reload orders list after successful creation
      context.read<OrdersCubit>().loadOrders(widget.token);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ түзүлдү!')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $errorText')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _orderCreateCubit,
      child: BlocBuilder<OrderCreateCubit, OrderCreateState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Жаңы заказ - ${widget.selectedCategory.name}'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      children: [
                        _buildStepIndicator(
                          step: 1,
                          label: 'Жөнөтүү',
                          isActive:
                              state.currentStep ==
                              OrderCreateStep.pickupLocation,
                          isCompleted: state.currentStep.index > 0,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Divider(thickness: 2),
                          ),
                        ),
                        _buildStepIndicator(
                          step: 2,
                          label: 'Жеткирүү',
                          isActive:
                              state.currentStep ==
                              OrderCreateStep.deliveryLocation,
                          isCompleted: state.currentStep.index > 1,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Divider(thickness: 2),
                          ),
                        ),
                        _buildStepIndicator(
                          step: 3,
                          label: 'Сыпаттама',
                          isActive:
                              state.currentStep == OrderCreateStep.description,
                          isCompleted: state.currentStep.index > 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.selectedCategory.icon,
                          size: 24,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.selectedCategory.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (state.currentStep == OrderCreateStep.pickupLocation) ...[
                    Text(
                      'Кайдан жөнөтүүнүн адресси',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Адресс киргизиңиз же картадан тандаңыз',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _fromAddressController,
                      hintText: 'Мисал: ул. Жибек Жолу, 123',
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    // Address suggestions
                    if (_fromAddressController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children:
                              _getFilteredSuggestions(
                                    _fromAddressController.text,
                                  )
                                  .take(5)
                                  .map(
                                    (address) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      title: Text(
                                        address,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _fromAddressController.text = address;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    CompactMapPreview(
                      initialLocation:
                          _selectedFromLocation ??
                          const LatLng(
                            latitude: 40.060518,
                            longitude: 70.819638,
                          ),
                      initialAddress: _fromAddressController.text.isNotEmpty
                          ? _fromAddressController.text
                          : null,
                      label: 'Картадан координата тандаңыз',
                      onLocationChanged: (location, address) {
                        setState(() {
                          _selectedFromLocation = location;
                          // Координатаны гана сактайбыз, адресс текстик поля өзгөрбөйт
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFromLocation != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.green.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Координата: ${_selectedFromLocation!.latitude.toStringAsFixed(6)}, ${_selectedFromLocation!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (state.currentStep ==
                      OrderCreateStep.deliveryLocation) ...[
                    Text(
                      'Кайда жеткирүүнүн адресси',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Адресс киргизиңиз же картадан тандаңыз',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _toAddressController,
                      hintText: 'Мисал: пр. Чуй, 456',
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    // Address suggestions
                    if (_toAddressController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children:
                              _getFilteredSuggestions(_toAddressController.text)
                                  .take(5)
                                  .map(
                                    (address) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      title: Text(
                                        address,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _toAddressController.text = address;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    CompactMapPreview(
                      initialLocation:
                          _selectedToLocation ??
                          const LatLng(
                            latitude: 40.070518,
                            longitude: 70.829638,
                          ),
                      initialAddress: _toAddressController.text.isNotEmpty
                          ? _toAddressController.text
                          : null,
                      label: 'Картадан координата тандаңыз',
                      onLocationChanged: (location, address) {
                        setState(() {
                          _selectedToLocation = location;
                          // Координатаны гана сактайбыз, адресс текстик поля өзгөрбөйт
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedToLocation != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.blue.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Координата: ${_selectedToLocation!.latitude.toStringAsFixed(6)}, ${_selectedToLocation!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (state.currentStep ==
                      OrderCreateStep.description) ...[
                    Text(
                      'Заказ сыпаттамасы',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // From Address Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Кайдан:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _fromAddressController.text.isNotEmpty
                                      ? _fromAddressController.text
                                      : 'Адрес тандалган жок',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // To Address Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Кайда:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _toAddressController.text.isNotEmpty
                                      ? _toAddressController.text
                                      : 'Адрес тандалган жок',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Distance Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.route,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Эсептелген аралык',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${state.calculatedDistance?.toStringAsFixed(1) ?? '0.0'} км',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Сыпаттама',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      hintText: 'Заказ тууралуу төлөкөлүнүп жаз...',
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          onPressed: _goToPreviousStep,
                          label: 'Артка',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppButton.primary(
                          onPressed: state.isLoading
                              ? null
                              : (state.currentStep ==
                                        OrderCreateStep.description
                                    ? _createOrder
                                    : _goToNextStep),
                          isLoading: state.isLoading,
                          label:
                              state.currentStep == OrderCreateStep.description
                              ? 'Түзүү'
                              : 'Улантуу',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : (isCompleted ? AppColors.accent2 : Colors.grey[300]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primary : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
