import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'web_map_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../orders/data/order_api.dart';
import '../../orders/data/order_status_audit_entry.dart';
import '../data/order_model.dart';
import '../../profile/data/user_api.dart';
import '../../home/presentation/order_payment_sheet.dart';
import 'order_chat_page.dart';
import 'cubit/order_detail_cubit.dart';
import 'cubit/order_detail_state.dart';

class OrderDetailPage extends StatefulWidget {
  final Order order;
  final String? token;
  final bool isCourier;

  const OrderDetailPage({
    super.key,
    required this.order,
    this.token,
    this.isCourier = false,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final OrderDetailCubit _detailCubit;
  final OrderApi _orderApi = OrderApi();
  bool _hasShownRatingPrompt = false;
  bool _isOrderAlreadyRated = false;
  bool _isRatingStatusLoaded = false;
  int _unreadChatCount = 0;
  bool _isStatusAuditLoading = false;
  List<OrderStatusAuditEntry> _statusAudit = const [];
  String? _statusAuditError;
  Position? _userPosition;
  Timer? _locationTimer;
  Timer? _orderRefreshTimer;
  final _userApi = UserApi();

  @override
  void initState() {
    super.initState();
    _detailCubit = OrderDetailCubit(
      initialOrder: widget.order,
      orderApi: OrderApi(),
    );
    _reloadCurrentOrderAndUnread();
    if (widget.isCourier) {
      _fetchUserLocation();
      _startLocationTimer();
    } else {
      _startOrderRefreshTimer();
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  void _startLocationTimer() {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final token = widget.token;
      if (token == null) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) setState(() => _userPosition = pos);
        await _userApi.updateLocation(token, pos.latitude, pos.longitude);
      } catch (_) {}
    });
  }

  void _startOrderRefreshTimer() {
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _reloadCurrentOrder();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _orderRefreshTimer?.cancel();
    _detailCubit.close();
    super.dispose();
  }

  Future<void> _reloadCurrentOrder() {
    return _detailCubit.reloadCurrentOrder(
      token: widget.token,
      isCourier: widget.isCourier,
    );
  }

  Future<void> _reloadCurrentOrderAndUnread() async {
    await _reloadCurrentOrder();
    await _loadRatingStatus();
    await _loadUnreadChatCount();
    await _loadStatusAudit();
  }

  Future<void> _loadStatusAudit({int? orderId}) async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) return;

    final targetOrderId = orderId ?? _detailCubit.state.currentOrder.id;

    if (!mounted) return;
    setState(() {
      _isStatusAuditLoading = true;
      _statusAuditError = null;
    });

    try {
      final entries = await _orderApi.getOrderStatusAudit(
        token: token,
        orderId: targetOrderId,
      );
      if (!mounted) return;
      setState(() {
        _statusAudit = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusAuditError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStatusAuditLoading = false;
        });
      }
    }
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'WAITING_COURIER':
      case 'PENDING':
        return 'Жаңы';
      case 'ACCEPTED':
        return 'Кабыл алынды — ишкана';
      case 'PREPARING':
        return 'Даярдалып жатат';
      case 'READY':
        return 'Даяр — Курьер күтүүдө';
      case 'PICKED_UP':
        return 'Кабыл алынды — Курьер';
      case 'IN_TRANSIT':
      case 'ON_THE_WAY':
        return 'Жеткирүүнү баштады';
      case 'DELIVERED':
        return 'Жеткирилди';
      case 'COMPLETED':
        return 'Аяктады';
      case 'CANCELLED':
        return 'Жокко чыгарылды';
      default:
        return status ?? '-';
    }
  }

  Widget _buildStatusAuditSection() {
    if (_isStatusAuditLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_statusAuditError != null) {
      return Text(
        _statusAuditError!,
        style: const TextStyle(color: AppColors.accent5, fontSize: 12),
      );
    }

    if (_statusAudit.isEmpty) {
      return const Text(
        'Статус тарыхы азырынча жок',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Column(
      children: _statusAudit.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_statusLabel(entry.fromStatus)} -> ${_statusLabel(entry.toStatus)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(entry.at),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _loadRatingStatus({int? orderId}) async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) return;

    final targetOrderId = orderId ?? _detailCubit.state.currentOrder.id;
    final isRated = await _orderApi.isOrderAlreadyRated(
      token: token,
      orderId: targetOrderId,
    );

    if (!mounted) return;
    setState(() {
      _isOrderAlreadyRated = isRated;
      _isRatingStatusLoaded = true;
    });
  }

  Future<void> _loadUnreadChatCount({int? orderId}) async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) return;

    final targetOrderId = orderId ?? _detailCubit.state.currentOrder.id;
    final unread = await _orderApi.getOrderUnreadChatCount(
      token: token,
      orderId: targetOrderId,
    );
    if (!mounted) return;
    setState(() {
      _unreadChatCount = unread;
    });
  }

  Widget _buildChatLabelWithBadge() {
    final displayCount = _unreadChatCount > 99
        ? '99+'
        : _unreadChatCount.toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Чат', style: TextStyle(fontSize: 12)),
        if (_unreadChatCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              displayCount,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accent4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _detailCubit,
      child: BlocBuilder<OrderDetailCubit, OrderDetailState>(
        builder: (context, state) {
          _maybeShowRatingPrompt(state.currentOrder);

          // Local variables from state for easier access
          final currentOrder = state.currentOrder;
          final isUpdatingStatus = state.isUpdatingStatus;

          final statusColor = _getCardColor(currentOrder.status);
          final accentColor = _getAccentColorForStatus(currentOrder.status);

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Text(
                'Заказ #${currentOrder.id}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  onPressed: isUpdatingStatus
                      ? null
                      : _reloadCurrentOrderAndUnread,
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main status card with gradient
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusColor.withAlpha(38),
                          statusColor.withAlpha(13),
                        ],
                      ),
                      border: Border.all(
                        color: statusColor.withAlpha(204),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Статус',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatusBadge(
                                  currentOrder.status,
                                  accentColor,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Дата',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(currentOrder.createdAt),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment button — shown for enterprise orders that are still pending
                  if (!widget.isCourier &&
                      currentOrder.enterpriseId != null &&
                      currentOrder.status == 'pending' &&
                      widget.token != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => OrderPaymentSheet(
                                token: widget.token!,
                                orderId: currentOrder.id,
                                enterpriseId: currentOrder.enterpriseId!,
                                amount: currentOrder.itemsTotal ?? currentOrder.estimatedPrice ?? 0,
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code, size: 20),
                          label: const Text(
                            'Төлөмдү тастыктоо',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4f46e5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Verification code section - shown only to regular users when order is delivered
                  if (!widget.isCourier &&
                      currentOrder.status == 'delivered' &&
                      currentOrder.verificationCode != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.withAlpha(60),
                            Colors.orange.withAlpha(25),
                          ],
                        ),
                        border: Border.all(color: Colors.orange, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withAlpha(80),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Курьерге берүү коду',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Text(
                              currentOrder.verificationCode!,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '⚠️ Бул кодду курьерге берип, төлөмүн аяктаңыз',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Info block ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Категория',
                          value: currentOrder.categoryName,
                          color: accentColor,
                          isFirst: true,
                        ),
                        _buildInfoDivider(),
                        _buildInfoRow(
                          icon: Icons.route,
                          label: 'Аралык',
                          value: '${currentOrder.distance.toStringAsFixed(1)} км',
                          color: accentColor,
                        ),
                        if (currentOrder.estimatedPrice != null) ...[
                          _buildInfoDivider(),
                          _buildInfoRow(
                            icon: Icons.local_shipping_outlined,
                            label: 'Жеткирүү баасы',
                            value: '${currentOrder.estimatedPrice?.round()} сом',
                            color: accentColor,
                            isLast: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Addresses block ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        // From
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor,
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 32,
                                    color: accentColor.withAlpha(60),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Чыгаруу',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      currentOrder.fromAddress,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // To
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF22c55e),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Жеткирүү',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      currentOrder.toAddress,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (currentOrder.fromLatitude != null &&
                      currentOrder.fromLongitude != null &&
                      currentOrder.toLatitude != null &&
                      currentOrder.toLongitude != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: kIsWeb
                          ? _WebMapPreview(
                              from: LatLng(
                                latitude: currentOrder.fromLatitude!,
                                longitude: currentOrder.fromLongitude!,
                              ),
                              to: LatLng(
                                latitude: currentOrder.toLatitude!,
                                longitude: currentOrder.toLongitude!,
                              ),
                              userLat: widget.isCourier ? _userPosition?.latitude : null,
                              userLon: widget.isCourier ? _userPosition?.longitude : null,
                              courierLat: widget.isCourier ? null : currentOrder.courierLatitude,
                              courierLon: widget.isCourier ? null : currentOrder.courierLongitude,
                            )
                          : GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => _FullScreenMapPage(
                                    from: LatLng(
                                      latitude: currentOrder.fromLatitude!,
                                      longitude: currentOrder.fromLongitude!,
                                    ),
                                    to: LatLng(
                                      latitude: currentOrder.toLatitude!,
                                      longitude: currentOrder.toLongitude!,
                                    ),
                                    isCourier: widget.isCourier,
                                    courierLat: widget.isCourier ? null : currentOrder.courierLatitude,
                                    courierLon: widget.isCourier ? null : currentOrder.courierLongitude,
                                  ),
                                ));
                              },
                              child: Stack(
                                children: [
                                  _OrderRouteMap(
                                    from: LatLng(
                                      latitude: currentOrder.fromLatitude!,
                                      longitude: currentOrder.fromLongitude!,
                                    ),
                                    to: LatLng(
                                      latitude: currentOrder.toLatitude!,
                                      longitude: currentOrder.toLongitude!,
                                    ),
                                    userLat: widget.isCourier ? _userPosition?.latitude : null,
                                    userLon: widget.isCourier ? _userPosition?.longitude : null,
                                    courierLat: widget.isCourier ? null : currentOrder.courierLatitude,
                                    courierLon: widget.isCourier ? null : currentOrder.courierLongitude,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.fullscreen, size: 20, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Аралык: ${currentOrder.distance.toStringAsFixed(1)} км',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Карта үчүн координата жетишсиз',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.location_on, color: accentColor, size: 20),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Order status audit timeline
                  Text(
                    'Статус тарыхы',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: _buildStatusAuditSection(),
                  ),
                  const SizedBox(height: 24),

                  // Description section
                  if (currentOrder.description.isNotEmpty) ...[
                    Text(
                      'Эмне жеткирилет',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        currentOrder.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Courier info section (for users only)
                  if (!widget.isCourier &&
                      currentOrder.courierName != null &&
                      currentOrder.status != 'completed') ...[
                    Text(
                      'Курьер',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withAlpha(38),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 20,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Аты',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentOrder.courierName!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Phone section
                          if (currentOrder.courierPhone != null) ...[
                            const SizedBox(height: 12),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor.withAlpha(38),
                                  ),
                                  child: Icon(
                                    Icons.phone,
                                    size: 20,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Телефон',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentOrder.courierPhone!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Contact buttons: WhatsApp, Call, Chat
                          if (currentOrder.courierId != null &&
                              currentOrder.status != 'completed') ...[
                            const SizedBox(height: 12),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // WhatsApp button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openWhatsAppChat(
                                      phone: currentOrder.courierPhone,
                                      displayName:
                                          currentOrder.courierName ?? 'курьер',
                                      orderId: currentOrder.id,
                                    ),
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text(
                                      'WhatsApp',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Call button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _makePhoneCall(
                                      phone: currentOrder.courierPhone,
                                      displayName:
                                          currentOrder.courierName ?? 'курьер',
                                    ),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text(
                                      'Чалуу',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent3,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Chat button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _openChatWithCourier(
                                        currentOrder: currentOrder,
                                      );
                                    },
                                    icon: const Icon(Icons.message, size: 16),
                                    label: _buildChatLabelWithBadge(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent4,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // User info section (for couriers)
                  if (widget.isCourier &&
                      currentOrder.userName != null &&
                      currentOrder.status != 'completed') ...[
                    Text(
                      'Колдонуучу',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withAlpha(38),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 20,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Аты',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentOrder.userName!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Phone section
                          if (currentOrder.userPhone != null) ...[
                            const SizedBox(height: 12),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor.withAlpha(38),
                                  ),
                                  child: Icon(
                                    Icons.phone,
                                    size: 20,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Телефон',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentOrder.userPhone!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Contact buttons (for both user and courier, hidden when completed)
                          if (currentOrder.courierId != null &&
                              currentOrder.status != 'completed') ...[
                            const SizedBox(height: 12),
                            Divider(color: AppColors.border),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openWhatsAppChat(
                                      phone: currentOrder.userPhone,
                                      displayName:
                                          currentOrder.userName ?? 'колдонуучу',
                                      orderId: currentOrder.id,
                                    ),
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text(
                                      'WhatsApp',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _makePhoneCall(
                                      phone: currentOrder.userPhone,
                                      displayName:
                                          currentOrder.userName ?? 'колдонуучу',
                                    ),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text(
                                      'Чалуу',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent3,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _openChatWithUser(
                                        currentOrder: currentOrder,
                                      );
                                    },
                                    icon: const Icon(Icons.message, size: 16),
                                    label: _buildChatLabelWithBadge(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent4,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons
                  if (widget.isCourier && widget.token != null) ...[
                    _buildStatusActionButtons(currentOrder, isUpdatingStatus),
                  ] else ...[
                    // Колдонуучу үчүн баскычтар
                    if (currentOrder.status == 'pending') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isUpdatingStatus ? null : _cancelUserOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent5,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.accent5
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isUpdatingStatus
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Жокко чыгаруу',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Курьер кабыл алган / жолдо болгон заказды жокко чыгаруу суроосу
                    if (currentOrder.status == 'accepted' ||
                        currentOrder.status == 'in_transit') ...[
                      _buildCancelRequestButton(currentOrder, isUpdatingStatus),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.primary(
                        onPressed: () => Navigator.pop(context),
                        label: 'Артка',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusActionButtons(Order currentOrder, bool isUpdatingStatus) {
    final isPending = currentOrder.status == 'pending';
    final isReady = currentOrder.status == 'ready'; // enterprise order ready for pickup
    final isPickedUp = currentOrder.status == 'picked_up';
    final isAccepted = currentOrder.status == 'accepted'; // legacy fallback
    final isInTransit = currentOrder.status == 'in_transit';
    final isDelivered = currentOrder.status == 'delivered';
    final isCompleted = currentOrder.status == 'completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPending || isReady)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton.primary(
              onPressed: isUpdatingStatus ? null : _acceptOrder,
              isLoading: isUpdatingStatus,
              label: 'Кабыл алуу',
            ),
          ),
        if (isPickedUp || isAccepted) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton.primary(
              onPressed: isUpdatingStatus ? null : _startDelivery,
              isLoading: isUpdatingStatus,
              label: 'Жеткирүүнү баштоо',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isUpdatingStatus ? null : _cancelCourierOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent5,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.accent5.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isUpdatingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Баш тартуу (-10 сом)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
        if (isInTransit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton.secondary(
              onPressed: isUpdatingStatus ? null : _markDelivered,
              isLoading: isUpdatingStatus,
              label: 'Жеткирилди',
            ),
          ),
        if (isDelivered)
          AppButton.secondary(
            onPressed: isUpdatingStatus ? null : _completeDelivery,
            isLoading: isUpdatingStatus,
            label: 'Аяктоо',
          ),
        if (isCompleted)
          AppButton.secondary(
            onPressed: () => Navigator.pop(context),
            label: 'Артка',
          ),
      ],
    );
  }

  Future<void> _acceptOrder() async {
    await _updateOrderStatus('accept');
  }

  Future<void> _startDelivery() async {
    await _updateOrderStatus('start');
  }

  Future<void> _completeDelivery() async {
    final code = await _showVerificationCodeDialog();
    if (code == null || code.isEmpty) return;

    try {
      await _detailCubit.completeDelivery(widget.token, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ ийгиликтүү аякталды'),
          backgroundColor: AppColors.accent4,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  Future<void> _markDelivered() async {
    try {
      await _detailCubit.markDelivered(widget.token);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ жеткирилди'),
          backgroundColor: AppColors.accent4,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String action) async {
    try {
      switch (action) {
        case 'accept':
          await _detailCubit.acceptOrder(widget.token);
          break;
        case 'start':
          await _detailCubit.startDelivery(widget.token);
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getStatusUpdateMessage(action)),
          backgroundColor: AppColors.accent4,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  String _getStatusUpdateMessage(String action) {
    switch (action) {
      case 'accept':
        return 'Заказ кабыл алынды';
      case 'start':
        return 'Жеткирүү баштады';
      case 'delivered':
        return 'Жеткирилди деп белгиленди';
      case 'complete':
        return 'Заказ аякталды';
      default:
        return 'Статус өзгөрттүлдү';
    }
  }

  Future<void> _cancelCourierOrder() async {
    // Тастыктоо диалогу
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Баш тартуу'),
        content: const Text(
          'Бул заказдан баш тартууну каалайсызбы?\n\nБалансыңыздан 10 сом кармалат.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent5),
            child: const Text('Ооба'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _detailCubit.cancelCourierOrder(widget.token);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заказдан баш тарттыңыз. Балансыңыздан 10 сом кармалды.',
          ),
          backgroundColor: AppColors.accent4,
        ),
      );

      // Артка кайтуу
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  Widget _buildCancelRequestButton(dynamic currentOrder, bool isUpdatingStatus) {
    final alreadyRequested = currentOrder.cancelRequested == true;

    if (alreadyRequested) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          border: Border.all(color: const Color(0xFFFFD966)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Color(0xFF92400E), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Жокко чыгаруу суроосу жөнөтүлдү. Администратордун чечимин күтүңүз.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isUpdatingStatus ? null : () => _sendCancelRequest(currentOrder),
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text(
          'Жокко чыгаруу суроосун жөнөт',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent5,
          side: BorderSide(color: AppColors.accent5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _sendCancelRequest(dynamic currentOrder) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Жокко чыгаруу суроосу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Курьер буга чейин жолго чыккан. Жокко чыгаруу суроосу администраторго жөнөтүлөт.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Себеп (милдеттүү эмес)',
                filled: true,
                fillColor: const Color(0xFFF4F6F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent5,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Жөнөтүү'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _detailCubit.requestCancelOrder(widget.token, reason: reasonController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Суроо жөнөтүлдү. Администратор кароого алат.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  Future<void> _cancelUserOrder() async {
    // Тастыктоо диалогу
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Жокко чыгаруу'),
        content: const Text('Бул заказды жокко чыгарууну каалайсызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent5),
            child: const Text('Ооба'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _detailCubit.cancelOrder(widget.token);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ жокко чыгарылды'),
          backgroundColor: AppColors.accent4,
        ),
      );

      // Артка кайтуу
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accent5,
        ),
      );
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() {
    return const Divider(height: 1, indent: 46, endIndent: 0, color: Color(0xFFf1f5f9));
  }

  Widget _buildStatusBadge(String status, Color accentColor) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppColors.accent2;
        textColor = Colors.white;
        label = 'Күтүүде';
        break;
      case 'preparing':
        bgColor = Colors.amber[700]!;
        textColor = Colors.white;
        label = 'Даярдалууда';
        break;
      case 'ready':
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = 'Даяр — алып кетүү';
        break;
      case 'accepted':
        bgColor = AppColors.accent3;
        textColor = Colors.white;
        label = 'Кабыл алынды';
        break;
      case 'in_transit':
      case 'picked_up':
        bgColor = AppColors.accent3;
        textColor = Colors.white;
        label = 'Жеткирүүдө';
        break;
      case 'delivered':
        bgColor = AppColors.accent4;
        textColor = Colors.white;
        label = 'Жеткирилди';
        break;
      case 'completed':
        bgColor = AppColors.accent4;
        textColor = Colors.white;
        label = 'Аякталды';
        break;
      case 'cancelled':
        bgColor = AppColors.accent5;
        textColor = Colors.white;
        label = 'Жокко чыгарылды';
        break;
      default:
        bgColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final utc = dateString.endsWith('Z') ? dateString : '${dateString}Z';
      final date = DateTime.parse(utc).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getCardColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.accent2;
      case 'preparing':
        return Colors.amber[700]!;
      case 'ready':
        return Colors.orange;
      case 'accepted':
      case 'in_transit':
      case 'picked_up':
        return AppColors.accent3;
      case 'completed':
      case 'delivered':
        return AppColors.accent4;
      case 'cancelled':
        return AppColors.accent5;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _openWhatsAppChat({
    required String? phone,
    required String displayName,
    required int orderId,
  }) async {
    if (phone == null || phone.trim().isEmpty) {
      _showInfoSnackBar('WhatsApp үчүн номер табылган жок: $displayName');
      return;
    }

    final normalizedPhone = _normalizePhoneForWhatsApp(phone);
    if (normalizedPhone.isEmpty) {
      _showInfoSnackBar('Телефон номери туура эмес: $displayName');
      return;
    }

    final initialMessage = Uri.encodeComponent(
      'Салам! Заказ #$orderId боюнча байланышып жатам.',
    );
    final whatsappUri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=$initialMessage',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        await _openWhatsAppWebFallback(whatsappUri);
      }
    } on PlatformException {
      await _openWhatsAppWebFallback(whatsappUri);
    } catch (_) {
      await _openWhatsAppWebFallback(whatsappUri);
    }
  }

  Future<void> _openWhatsAppWebFallback(Uri whatsappUri) async {
    final openedInBrowser = await launchUrl(
      whatsappUri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (!openedInBrowser && mounted) {
      _showInfoSnackBar('WhatsApp ачылбай калды. Кайра аракет кылыңыз.');
    }
  }

  String _normalizePhoneForWhatsApp(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.startsWith('+')) {
      return normalized.substring(1);
    }
    return normalized;
  }

  Future<void> _makePhoneCall({
    required String? phone,
    required String displayName,
  }) async {
    if (phone == null || phone.trim().isEmpty) {
      _showInfoSnackBar('Чалуу үчүн номер табылган жок: $displayName');
      return;
    }

    final normalizedPhone = _normalizePhoneForCall(phone);
    if (normalizedPhone.isEmpty) {
      _showInfoSnackBar('Телефон номери туура эмес: $displayName');
      return;
    }

    final callUri = Uri(scheme: 'tel', path: normalizedPhone);

    try {
      var opened = await launchUrl(
        callUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!opened) {
        opened = await launchUrl(callUri, mode: LaunchMode.externalApplication);
      }

      if (!opened && mounted) {
        final platformHint = defaultTargetPlatform == TargetPlatform.iOS
            ? ' (iOS симулятордо чалуу иштебейт)'
            : '';
        _showInfoSnackBar('Чалуу функциясы иштебеди$platformHint');
      }
    } on PlatformException {
      if (mounted) {
        _showInfoSnackBar('Чалуу функциясы жеткиликтүү эмес');
      }
    } catch (_) {
      if (mounted) {
        _showInfoSnackBar('Чалуу функциясы иштебеди');
      }
    }
  }

  String _normalizePhoneForCall(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return '';

    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    return cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent5,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openChatWithCourier({required Order currentOrder}) async {
    if (widget.token == null || widget.token!.trim().isEmpty) {
      _showInfoSnackBar('Сессия бүттү. Кайра кириңиз.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatPage(
          token: widget.token!,
          orderId: currentOrder.id,
          counterpartyName: currentOrder.courierName ?? 'Курьер',
          counterpartyId: currentOrder.courierId,
        ),
      ),
    );

    await _loadUnreadChatCount(orderId: currentOrder.id);
  }

  Future<void> _openChatWithUser({required Order currentOrder}) async {
    if (widget.token == null || widget.token!.trim().isEmpty) {
      _showInfoSnackBar('Сессия бүттү. Кайра кириңиз.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatPage(
          token: widget.token!,
          orderId: currentOrder.id,
          counterpartyName: currentOrder.userName ?? 'Колдонуучу',
          counterpartyId: currentOrder.userId,
        ),
      ),
    );

    await _loadUnreadChatCount(orderId: currentOrder.id);
  }

  Future<void> showCodeGeneratedDialog(String code) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Тастыктоо коду',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Бул кодду колдонуучуга көрсөтүңүз:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Колдонуучу бул кодду тастыктаганда гана заказ аякталат',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Жабуу'),
            ),
          ],
        );
      },
    );
  }

  void _maybeShowRatingPrompt(Order currentOrder) {
    if (_hasShownRatingPrompt) return;
    if (widget.token == null) return;
    if (currentOrder.status != 'completed') return;
    if (!_isRatingStatusLoaded) return;
    if (_isOrderAlreadyRated) return;

    _hasShownRatingPrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showRatingDialog(currentOrder);
    });
  }

  Future<void> _showRatingDialog(Order currentOrder) async {
    final commentController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (sheetCtx) => _RatingBottomSheet(
          isCourier: widget.isCourier,
          onSubmit: (rating, comment) async {
            if (widget.isCourier) {
              await _orderApi.rateUser(
                token: widget.token!,
                orderId: currentOrder.id,
                rating: rating,
                comment: comment,
              );
            } else {
              await _orderApi.rateCourier(
                token: widget.token!,
                orderId: currentOrder.id,
                rating: rating,
                comment: comment,
              );
            }
          },
          onSuccess: () {
            if (!mounted) return;
            setState(() => _isOrderAlreadyRated = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Баалоо ийгиликтүү сакталды'),
                  ],
                ),
                backgroundColor: AppColors.accent4,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          },
          onAlreadyRated: () {
            if (!mounted) return;
            setState(() => _isOrderAlreadyRated = true);
          },
        ),
      );
    } finally {
      try {
        commentController.dispose();
      } catch (_) {}
    }
  }

  Future<String?> _showVerificationCodeDialog() async {
    final TextEditingController codeController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Тастыктоо коду',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Колдонуучудан алган 6 цифралуу кодду киргизиңиз:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim();
                if (code.length == 6) {
                  Navigator.of(context).pop(code);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('6 цифра киргизиңиз'),
                      backgroundColor: AppColors.accent5,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Тастыктоо'),
            ),
          ],
        );
      },
    );
  }

  Color _getAccentColorForStatus(String status) {
    switch (status) {
      case 'pending':
        return AppColors.accent2;
      case 'preparing':
        return Colors.amber[700]!;
      case 'ready':
        return Colors.orange;
      case 'accepted':
      case 'in_transit':
      case 'picked_up':
        return AppColors.accent3;
      case 'completed':
      case 'delivered':
        return AppColors.accent4;
      case 'cancelled':
        return AppColors.accent5;
      default:
        return AppColors.primary;
    }
  }
}

class _FullScreenMapPage extends StatefulWidget {
  const _FullScreenMapPage({
    required this.from,
    required this.to,
    this.isCourier = false,
    this.courierLat,
    this.courierLon,
  });

  final LatLng from;
  final LatLng to;
  final bool isCourier;
  final double? courierLat;
  final double? courierLon;

  @override
  State<_FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<_FullScreenMapPage> {
  Position? _userPosition;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isCourier) {
      _fetchLocation();
      _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchLocation());
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _OrderRouteMap(
            from: widget.from,
            to: widget.to,
            userLat: widget.isCourier ? _userPosition?.latitude : null,
            userLon: widget.isCourier ? _userPosition?.longitude : null,
            courierLat: widget.isCourier ? null : widget.courierLat,
            courierLon: widget.isCourier ? null : widget.courierLon,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, size: 22, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRouteMap extends StatefulWidget {
  const _OrderRouteMap({
    required this.from,
    required this.to,
    this.userLat,
    this.userLon,
    this.courierLat,
    this.courierLon,
    this.fullscreen = false,
  });

  final LatLng from;
  final LatLng to;
  final double? userLat;
  final double? userLon;
  final double? courierLat;
  final double? courierLon;
  final bool fullscreen;

  @override
  State<_OrderRouteMap> createState() => _OrderRouteMapState();
}

class _OrderRouteMapState extends State<_OrderRouteMap> {
  late WebViewController _controller; // only used on non-web
  bool _isLoading = true;
  late String _webViewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webViewId =
          'ymap_${widget.from.latitude}_${widget.from.longitude}_${widget.to.latitude}_${widget.to.longitude}_${DateTime.now().microsecondsSinceEpoch}';
      registerWebIframe(
        _webViewId,
        _buildHtml(widget.from, widget.to, widget.userLat, widget.userLon,
            widget.courierLat, widget.courierLon),
      );
    } else {
      _buildController();
    }
  }

  @override
  void didUpdateWidget(_OrderRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) return;
    // Full reload only if route endpoints changed
    if (oldWidget.from.latitude != widget.from.latitude ||
        oldWidget.from.longitude != widget.from.longitude ||
        oldWidget.to.latitude != widget.to.latitude ||
        oldWidget.to.longitude != widget.to.longitude) {
      _buildController();
      return;
    }
    // Smooth JS updates for moving markers
    if (widget.userLat != null && widget.userLon != null &&
        (oldWidget.userLat != widget.userLat || oldWidget.userLon != widget.userLon)) {
      _controller.runJavaScript('if(window.updateUserPos) updateUserPos(${widget.userLat}, ${widget.userLon});');
    }
    if (widget.courierLat != null && widget.courierLon != null &&
        (oldWidget.courierLat != widget.courierLat || oldWidget.courierLon != widget.courierLon)) {
      _controller.runJavaScript('if(window.updateCourierPos) updateCourierPos(${widget.courierLat}, ${widget.courierLon});');
    }
  }

  void _buildController() {
    _isLoading = true;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadHtmlString(
        _buildHtml(widget.from, widget.to, widget.userLat, widget.userLon,
            widget.courierLat, widget.courierLon),
        baseUrl: 'https://yandex.ru',
      );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (widget.fullscreen) {
        // Fullscreen: толук iframe карта
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: buildWebIframeMap(
            _buildHtml(widget.from, widget.to, widget.userLat, widget.userLon,
                widget.courierLat, widget.courierLon),
            _webViewId,
          ),
        );
      }
      // Preview: static image + tap => dialog
      return _WebMapPreview(
        from: widget.from,
        to: widget.to,
        userLat: widget.userLat,
        userLon: widget.userLon,
        courierLat: widget.courierLat,
        courierLon: widget.courierLon,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _buildHtml(LatLng from, LatLng to, double? userLat, double? userLon,
      [double? courierLat, double? courierLon]) =>
      _buildYandexMapHtml(from, to, userLat, userLon, courierLat, courierLon);
}

String _buildYandexMapHtml(LatLng from, LatLng to, double? userLat,
    double? userLon, [double? courierLat, double? courierLon]) {
    final centerLat = (from.latitude + to.latitude) / 2;
    final centerLon = (from.longitude + to.longitude) / 2;
    final hasUser = userLat != null && userLon != null;
    final hasCourier = courierLat != null && courierLon != null;
    final initUserMark = hasUser
        ? 'userMark = new ymaps.Placemark([$userLat, $userLon], { hintContent: "Менин жайгашкан жерим" }, { preset: "islands#blueCircleDotIcon" }); map.geoObjects.add(userMark);'
        : '';
    final initCourierMark = hasCourier
        ? 'courierMark = new ymaps.Placemark([$courierLat, $courierLon], { hintContent: "Курьер" }, { preset: "islands#orangeDeliveryIcon" }); map.geoObjects.add(courierMark);'
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <script src="https://api-maps.yandex.ru/2.1/?lang=ru_RU" type="text/javascript"></script>
  <style>
    html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    ymaps.ready(function () {
      var map = new ymaps.Map('map', {
        center: [$centerLat, $centerLon],
        zoom: 12,
        controls: ['zoomControl']
      });

      var from = [${from.latitude}, ${from.longitude}];
      var to = [${to.latitude}, ${to.longitude}];

      map.geoObjects.add(new ymaps.Placemark(from, { hintContent: 'Чыгаруу' }, { preset: 'islands#greenDotIcon' }));
      map.geoObjects.add(new ymaps.Placemark(to, { hintContent: 'Жеткирүү' }, { preset: 'islands#redDotIcon' }));

      var userMark = null;
      var courierMark = null;
      $initUserMark
      $initCourierMark

      window.updateUserPos = function(lat, lon) {
        if (userMark) {
          userMark.geometry.setCoordinates([lat, lon]);
        } else {
          userMark = new ymaps.Placemark([lat, lon], { hintContent: 'Менин жайгашкан жерим' }, { preset: 'islands#blueCircleDotIcon' });
          map.geoObjects.add(userMark);
        }
      };
      window.updateCourierPos = function(lat, lon) {
        if (courierMark) {
          courierMark.geometry.setCoordinates([lat, lon]);
        } else {
          courierMark = new ymaps.Placemark([lat, lon], { hintContent: 'Курьер' }, { preset: 'islands#orangeDeliveryIcon' });
          map.geoObjects.add(courierMark);
        }
      };

      function drawFallback() {
        map.geoObjects.add(new ymaps.Polyline([from, to], {}, { strokeColor: '#1E88E5', strokeWidth: 4, opacity: 0.8 }));
        map.setBounds(map.geoObjects.getBounds(), { checkZoomRange: true, zoomMargin: 32 });
      }

      var fromLon = ${from.longitude};
      var fromLat = ${from.latitude};
      var toLon = ${to.longitude};
      var toLat = ${to.latitude};

      fetch('https://router.project-osrm.org/route/v1/driving/' + fromLon + ',' + fromLat + ';' + toLon + ',' + toLat + '?overview=full&geometries=geojson')
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (data.code === 'Ok' && data.routes && data.routes[0]) {
            var coords = data.routes[0].geometry.coordinates.map(function(c) { return [c[1], c[0]]; });
            map.geoObjects.add(new ymaps.Polyline(coords, {}, { strokeColor: '#1E88E5', strokeWidth: 5, opacity: 0.9 }));
            map.setBounds(map.geoObjects.getBounds(), { checkZoomRange: true, zoomMargin: 32 });
          } else {
            drawFallback();
          }
        })
        .catch(function() { drawFallback(); });
    });
  </script>
</body>
</html>
  ''';
}

// ─── Web Map Preview (web-only: static thumbnail → fullscreen iframe dialog) ──

class _WebMapPreview extends StatelessWidget {
  const _WebMapPreview({
    required this.from,
    required this.to,
    this.userLat,
    this.userLon,
    this.courierLat,
    this.courierLon,
  });

  final LatLng from;
  final LatLng to;
  final double? userLat;
  final double? userLon;
  final double? courierLat;
  final double? courierLon;

  String get _staticUrl {
    final centerLat = (from.latitude + to.latitude) / 2;
    final centerLon = (from.longitude + to.longitude) / 2;
    final fromPt = '${from.longitude},${from.latitude},pm2grm';
    final toPt = '${to.longitude},${to.latitude},pm2rdm';
    String pt = '$fromPt~$toPt';
    if (courierLat != null && courierLon != null) {
      pt += '~$courierLon,$courierLat,pm2blm';
    }
    return 'https://static-maps.yandex.ru/1.x/?ll=$centerLon,$centerLat&z=12&size=650,400&l=map&pt=$pt';
  }

  void _openFullscreen(BuildContext context) {
    final viewId =
        'ymap_fs_${from.latitude}_${from.longitude}_${DateTime.now().microsecondsSinceEpoch}';
    final html = _buildYandexMapHtml(from, to, userLat, userLon, courierLat, courierLon);
    registerWebIframe(viewId, html);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: buildWebIframeMap(html, viewId),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, size: 22, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _staticUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(
                  color: Color(0xFFE8E8E8),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE8E8E8),
                child: Center(
                  child: Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen, size: 20, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rating Bottom Sheet ─────────────────────────────────────────────────────

class _RatingBottomSheet extends StatefulWidget {
  const _RatingBottomSheet({
    required this.isCourier,
    required this.onSubmit,
    required this.onSuccess,
    required this.onAlreadyRated,
  });

  final bool isCourier;
  final Future<void> Function(int rating, String comment) onSubmit;
  final VoidCallback onSuccess;
  final VoidCallback onAlreadyRated;

  @override
  State<_RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<_RatingBottomSheet> {
  int _selectedRating = 0;
  bool _isSubmitting = false;
  final _commentCtrl = TextEditingController();

  static const _labels = ['Жаман', 'Начар', 'Жакшы', 'Абдан жакшы', 'Мыкты!'];
  static const _starColor = Color(0xFFFFB800);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0 || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_selectedRating, _commentCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('already rated')) {
        Navigator.of(context).pop();
        widget.onAlreadyRated();
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.accent5,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _starColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: _starColor, size: 34),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.isCourier
                ? 'Колдонуучуну баалаңыз'
                : 'Курьерди баалаңыз',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isCourier
                ? 'Колдонуучунун маданияттуулугу кандай болду?'
                : 'Курьердин кызматы кандай болду?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7B7B93)),
          ),
          const SizedBox(height: 28),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final val = i + 1;
              final filled = val <= _selectedRating;
              return GestureDetector(
                onTap: _isSubmitting
                    ? null
                    : () {
                        setState(() => _selectedRating = val);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Transform.scale(
                    scale: filled ? 1.15 : 1.0,
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: filled ? _starColor : const Color(0xFFD0D0D0),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedRating > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _labels[_selectedRating - 1],
                      key: ValueKey(_selectedRating),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _starColor,
                      ),
                    ),
                  )
                : const SizedBox(height: 34, key: ValueKey(0)),
          ),

          const SizedBox(height: 20),

          // Comment field
          TextField(
            controller: _commentCtrl,
            enabled: !_isSubmitting,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Комментарий жазыңыз (милдеттүү эмес)',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
              filled: true,
              fillColor: const Color(0xFFF7F7F9),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    foregroundColor: const Color(0xFF7B7B93),
                  ),
                  child: const Text('Кийин',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: _selectedRating > 0
                        ? AppColors.primary
                        : const Color(0xFFD0D0D0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _selectedRating > 0 ? _submit : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Жиберүү',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
