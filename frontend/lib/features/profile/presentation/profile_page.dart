// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:frontend/features/profile/presentation/cubit/profile_state.dart';
import 'package:frontend/features/profile/presentation/notifications_page.dart';
import 'package:frontend/features/profile/presentation/transaction_history_page.dart';
import 'package:frontend/features/profile/presentation/contact_admin_page.dart';
import 'package:frontend/features/profile/presentation/change_password_page.dart';
import 'package:frontend/features/profile/presentation/about_page.dart';
import 'package:frontend/features/profile/presentation/how_to_order_page.dart';
import '../data/referral_api.dart';
import '../data/user_api.dart' as user_api_lib;
import 'package:frontend/features/profile/presentation/topup_page.dart';
import 'package:frontend/features/profile/presentation/topup_history_page.dart';
import 'package:frontend/features/advertisements/presentation/advertisements_page.dart';

import '../data/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.token, required this.onLogout});

  final String token;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileCubit get _profileCubit => context.read<ProfileCubit>();
  bool _statsTriggerred = false;
  bool _courierBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = _profileCubit.state.user;
      if (user != null && user.isCourier && !_statsTriggerred) {
        _statsTriggerred = true;
        _profileCubit.loadCourierStats(widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (prev, curr) =>
          prev.user == null && curr.user != null && curr.user!.isCourier,
      listener: (context, state) {
        if (!_statsTriggerred) {
          _statsTriggerred = true;
          _profileCubit.loadCourierStats(widget.token);
        }
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.token.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Профиль',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Сиз конок катары кирдиңиз',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Буйрутма берүү, тарыхты көрүү жана аккаунтту башкаруу үчүн кириңиз же катталыңыз.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton.primary(
                  onPressed: widget.onLogout,
                  label: 'Кирүү / Катталуу',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profileState = context.watch<ProfileCubit>().state;
    final User? user = profileState.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsPage(
                        token: widget.token,
                        userId: user?.id ?? 0,
                      ),
                    ),
                  );
                  if (mounted) {
                    _profileCubit.loadUser(widget.token, silent: true);
                  }
                },
              ),
              if (profileState.unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      profileState.unreadNotifications > 99
                          ? '99+'
                          : '${profileState.unreadNotifications}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: _showEditBottomSheet,
          ),
        ],
      ),
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileState.error != null
          ? _buildError(profileState.error!)
          : user != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (user.balance <= 100) ...[
                    _buildLowBalanceBanner(user),
                    const SizedBox(height: 12),
                  ],
                  if (!user.isCourier && !_courierBannerDismissed) ...[
                    _buildCourierRecruitBanner(),
                    const SizedBox(height: 12),
                  ],
                  _buildProfileCard(
                    user,
                    ratingAverage: profileState.ratingAverage,
                    ratingTotal: profileState.ratingTotalReviews,
                  ),
                  const SizedBox(height: 14),
                  if (user.isCourier) ...[
                    _buildTransportCard(user),
                    const SizedBox(height: 14),
                  ],
                  _buildBalanceCard(user),
                  const SizedBox(height: 14),
                  if (user.isCourier) ...[
                    _buildStatsSection(profileState),
                    const SizedBox(height: 14),
                  ],
                  _buildMenuSection(user),
                  const SizedBox(height: 14),
                  _buildReferralCard(),
                  const SizedBox(height: 14),
                  _buildLogoutButton(),
                  const SizedBox(height: 12),
                  _buildDeleteAccountButton(),
                  const SizedBox(height: 24),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ── Low balance banner ────────────────────────────────────────────────────────

  Widget _buildLowBalanceBanner(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Балансыңыз аз',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A5800),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Учурдагы баланс: ${user.balance.toStringAsFixed(0)} сом. Балансыңды толукта!',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E7C00),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TopupPage(token: widget.token)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Толуктоо',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Courier recruit banner ─────────────────────────────────────────────────────

  Widget _buildCourierRecruitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🚴', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Курьер болуп иштөөнү каалайсыңбы?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3730A3),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Администраторго кайрылыңыз',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _courierBannerDismissed = true),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFC7D2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Color(0xFF3730A3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ────────────────────────────────────────────────────────────

  Widget _buildProfileCard(
    User user, {
    double ratingAverage = 0,
    int ratingTotal = 0,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Phone
          Text(
            user.phone,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          // ID badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ID: ${user.uniqueId}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Rating row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB300),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  ratingTotal > 0 ? ratingAverage.toStringAsFixed(1) : '—',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A5800),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ratingTotal > 0 ? '$ratingTotal баалоо' : 'Баалоо жок',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E7C00),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard(User user) {
    final plate = user.courierVehiclePlate?.trim();
    final brand = user.courierVehicleBrand?.trim();
    final color = user.courierVehicleColor?.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showTransportBottomSheet(user),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _transportIcon(user.courierTransport),
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Жеткирүү транспорту',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.courierTransportLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (plate != null && plate.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Мамлекеттик номер: $plate',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (brand != null && brand.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        color != null && color.isNotEmpty
                            ? '$brand · $color'
                            : brand,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _transportIcon(String transport) {
    switch (transport) {
      case 'car':
        return Icons.directions_car_filled_rounded;
      case 'cargo':
        return Icons.local_shipping_rounded;
      case 'scooter':
        return Icons.electric_scooter_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }

  Future<void> _showTransportBottomSheet(User user) async {
    var selected = user.courierTransport;
    var error = '';
    var saving = false;
    final plateController = TextEditingController(
      text: user.courierVehiclePlate ?? '',
    );
    final brandController = TextEditingController(
      text: user.courierVehicleBrand ?? '',
    );
    final colorController = TextEditingController(
      text: user.courierVehicleColor ?? '',
    );
    const options = [
      ('walking', 'Жөө', 'Транспортсуз'),
      ('car', 'Жеңил автоунаа', 'Ыкчам жеткирүү'),
      ('cargo', 'Жүк ташуучу', 'Чоң жүктөр үчүн'),
      ('scooter', 'Скутер', 'Шаар ичинде'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final requiresPlate = selected == 'car' || selected == 'cargo';
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Жеткирүү транспорту',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Кардар заказ учурунда сиздин транспортту көрөт',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.48,
                            ),
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options[index];
                          final active = selected == option.$1;
                          return InkWell(
                            onTap: saving
                                ? null
                                : () => setSheetState(() {
                                    selected = option.$1;
                                    error = '';
                                  }),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary.withOpacity(0.08)
                                    : const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: active ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _transportIcon(option.$1),
                                    size: 25,
                                    color: active
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    option.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.$3,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (requiresPlate) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: plateController,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 32,
                          decoration: InputDecoration(
                            labelText: 'Мамлекеттик номер',
                            hintText: 'Мисалы: 01 KG 123 ABC',
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.pin_outlined,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF4F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: brandController,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 64,
                          decoration: InputDecoration(
                            labelText: 'Автоунаанын маркасы',
                            hintText: 'Мисалы: Toyota Camry',
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.directions_car_outlined,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF4F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: colorController,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 64,
                          decoration: InputDecoration(
                            labelText: 'Автоунаанын түсү',
                            hintText: 'Мисалы: Ак',
                            counterText: '',
                            prefixIcon: const Icon(
                              Icons.palette_outlined,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF4F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          error,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final plate = plateController.text.trim();
                                  final brand = brandController.text.trim();
                                  final color = colorController.text.trim();
                                  if (requiresPlate && plate.isEmpty) {
                                    setSheetState(() {
                                      error =
                                          'Автоунаанын мамлекеттик номерин жазыңыз';
                                    });
                                    return;
                                  }
                                  if (requiresPlate && brand.isEmpty) {
                                    setSheetState(() {
                                      error = 'Автоунаанын маркасын жазыңыз';
                                    });
                                    return;
                                  }
                                  if (requiresPlate && color.isEmpty) {
                                    setSheetState(() {
                                      error = 'Автоунаанын түсүн жазыңыз';
                                    });
                                    return;
                                  }
                                  setSheetState(() {
                                    saving = true;
                                    error = '';
                                  });
                                  try {
                                    await _profileCubit.updateProfile(
                                      widget.token,
                                      courierTransport: selected,
                                      courierVehiclePlate: requiresPlate
                                          ? plate
                                          : null,
                                      courierVehicleBrand: requiresPlate
                                          ? brand
                                          : null,
                                      courierVehicleColor: requiresPlate
                                          ? color
                                          : null,
                                    );
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Транспорт маалыматы сакталды',
                                        ),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (exception) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {
                                      saving = false;
                                      error = exception.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Сактоо',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    plateController.dispose();
    brandController.dispose();
    colorController.dispose();
  }

  // ── Balance card ─────────────────────────────────────────────────────────────

  Widget _buildBalanceCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'УЧУРДАГЫ БАЛАНС',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBalance(user.balance),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  'сом',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (context.watch<ProfileCubit>().state.pendingTopupAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${context.watch<ProfileCubit>().state.pendingTopupAmount.toStringAsFixed(0)} сом тастыкталууда',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent2,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopupPage(token: widget.token),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Балансты толуктоо',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(double balance) {
    final intBalance = balance.toInt();
    if (intBalance >= 1000) {
      final thousands = intBalance ~/ 1000;
      final remainder = intBalance % 1000;
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return intBalance.toString();
  }

  // ── Stats section ─────────────────────────────────────────────────────────────

  Widget _buildStatsSection(ProfileState profileState) {
    final stats = profileState.courierStats;
    final isLoading = profileState.isCourierStatsLoading;
    final statsError = profileState.courierStatsError;

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (stats == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_outlined, size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              statsError ?? 'Статистиканы жүктөө мүмкүн болгон жок',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _profileCubit.loadCourierStats(widget.token),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Кайра жүктөө'),
            ),
          ],
        ),
      );
    }

    final todayCompleted =
        (stats['today_completed_orders'] as num?)?.toInt() ?? 0;
    final todayEarnings = (stats['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final totalCompleted =
        (stats['total_completed_orders'] as num?)?.toInt() ?? 0;
    final totalEarnings = (stats['total_earnings'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        _buildStatCard(
          title: 'БҮГҮНКҮ СТАТИСТИКА',
          items: [
            _StatItem(
              icon: Icons.shopping_bag_outlined,
              value: todayCompleted.toString(),
              label: 'ЗАКАЗДАР',
            ),
            _StatItem(
              icon: Icons.account_balance_wallet_outlined,
              value: todayEarnings.toStringAsFixed(0),
              label: 'ТАПКАН АКЧА (С)',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildStatCard(
          title: 'ЖАЛПЫ СТАТИСТИКА',
          items: [
            _StatItem(
              icon: Icons.local_shipping_outlined,
              value: _formatLargeNumber(totalCompleted),
              label: 'ЖАЛПЫ ЗАКАЗДАР',
            ),
            _StatItem(
              icon: Icons.attach_money,
              value: _formatLargeNumber(totalEarnings.toInt()),
              label: 'ЖАЛПЫ КИРЕШЕ',
            ),
          ],
        ),
      ],
    );
  }

  String _formatLargeNumber(int value) {
    if (value >= 1000) {
      final thousands = value ~/ 1000;
      final remainder = value % 1000;
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return value.toString();
  }

  Widget _buildStatCard({
    required String title,
    required List<_StatItem> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: items.map((item) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: item == items.last ? 0 : 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, color: AppColors.primary, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Menu section ──────────────────────────────────────────────────────────────

  /// Invite code, how many friends joined with it and what that earned.
  /// Hidden until the summary loads so the profile never shows an empty box.
  Widget _buildReferralCard() {
    final summary = _referrals;
    if (summary == null || summary.code.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Досуңузду чакырыңыз',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Досуңуз катталганда сиздин кодуңузду жазса, '
            'балансыңызга ${summary.bonus.round()} сом кошулат.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.brown[400],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.code,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: summary.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Код көчүрүлдү'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 19,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _shareApp,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Бөлүшүү'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (summary.invitedCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Colors.brown[400]),
                const SizedBox(width: 6),
                Text(
                  '${summary.invitedCount} дос кошулду',
                  style: TextStyle(fontSize: 13, color: Colors.brown[400]),
                ),
                const Spacer(),
                Text(
                  '${summary.earned.round()} сом табылды',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection(User user) {
    final items = [
      _MenuItem(
        icon: Icons.campaign_outlined,
        label: 'Менин жарнамаларым',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdvertisementsPage(token: widget.token, mineOnly: true),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.help_outline,
        label: 'Кантип заказ берем?',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HowToOrderPage()),
        ),
      ),
      _MenuItem(
        icon: Icons.receipt_long_outlined,
        label: 'Транзакциялардын тарыхы',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionHistoryPage(token: widget.token),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Топап тарыхы',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopupHistoryPage(token: widget.token),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.lock_outline,
        label: 'Сырсөздү өзгөртүү',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangePasswordPage(token: widget.token),
          ),
        ),
      ),
      _MenuItem(
        icon: Icons.support_agent_outlined,
        label: 'Администраторго жазуу',
        onTap: _openSupportChat,
      ),
      _MenuItem(
        icon: Icons.share_outlined,
        label: 'Достор менен бөлүшүү',
        onTap: _shareApp,
      ),
      _MenuItem(
        icon: Icons.info_outline,
        label: 'Программа жөнүндө',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutPage()),
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 20, color: AppColors.primary),
                ),
                title: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(height: 1, indent: 68, color: const Color(0xFFF0F0F0)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Logout button ──────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _showLogoutDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF0F0),
          foregroundColor: AppColors.danger,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(Icons.logout, size: 20, color: AppColors.danger),
        label: Text(
          'Чыгуу',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton.icon(
        onPressed: _showDeleteAccountDialog,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(
          Icons.delete_forever_outlined,
          size: 20,
          color: AppColors.danger,
        ),
        label: const Text(
          'Аккаунтту өчүрүү',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.danger,
          ),
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────────

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: () => _profileCubit.loadUser(widget.token),
              label: 'Кайра жүктөө',
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Чыгуу',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const Text(
          'Сиз чындап эле чыккыңыз келеби?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Жок',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ооба',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Аккаунтту өчүрүү',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        content: const Text(
          'Сиз чындап эле аккаунтуңузду биротоло өчүргүңүз келеби?\n\nБул аракетти артка кайтарууга болбойт. Бардык буйрутмаларыңыз жана жеке маалыматтарыңыз өчүрүлөт.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Жокко чыгаруу',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ооба, өчүрүү',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.danger),
      ),
    );
    try {
      await user_api_lib.UserApi().deleteAccount(widget.token);
      if (!mounted) return;
      Navigator.pop(context); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аккаунтуңуз ийгиликтүү өчүрүлдү'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ката: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  /// Share the app with the logo attached, so the post carries a picture in
  /// WhatsApp/Instagram instead of a bare link.
  ReferralSummary? _referrals;

  Future<void> _loadReferrals() async {
    final summary = await ReferralApi().fetch(widget.token);
    if (!mounted) return;
    setState(() => _referrals = summary);
  }

  Future<void> _shareApp() async {
    final code = _referrals?.code ?? '';
    // The friend types this code when registering — that is what links the
    // signup back to the inviter and pays the bonus.
    final text = code.isEmpty
        ? '🚀 Баткен Экспресс — тез жана ыңгайлуу жеткирүү кызматы!\n'
              'Буйрутма бер: https://batjetkiret.vercel.app'
        : '🚀 Баткен Экспресс — тез жана ыңгайлуу жеткирүү кызматы!\n'
              'Тиркемени жүктөп ал: https://batjetkiret.vercel.app\n\n'
              'Катталганда менин кодумду жаз: $code';

    try {
      final logo = await rootBundle.load('assets/images/logo.png');
      final file = File('${Directory.systemTemp.path}/batken_express.png');
      await file.writeAsBytes(logo.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: text,
          subject: 'Баткен Экспресс',
        ),
      );
    } catch (_) {
      // Attaching the picture is a bonus — never block sharing on it.
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Баткен Экспресс'),
      );
    }
  }

  void _openSupportChat() {
    final user = context.read<ProfileCubit>().state.user;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactAdminPage(
          token: widget.token,
          userId: user.id,
          startChatFn: () =>
              user_api_lib.UserApi().startSupportChat(widget.token),
        ),
      ),
    );
  }

  void _showEditBottomSheet() {
    final currentUser = context.read<ProfileCubit>().state.user;
    final nameController = TextEditingController(text: currentUser?.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Профилди өзгөртүү',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Аты-жөнү',
                  hintText: 'Атыңызды киргизиңиз',
                  filled: true,
                  fillColor: const Color(0xFFF4F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Жокко чыгаруу',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _updateProfile(nameController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Сактоо',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile(String name) async {
    if (name.isEmpty) return;
    try {
      await _profileCubit.updateProfile(widget.token, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Профил жаңыланды'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ── Helper classes ─────────────────────────────────────────────────────────────

class _StatItem {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
