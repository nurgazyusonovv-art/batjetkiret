import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/orders/data/order_api.dart';
import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/order_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Follows a delivery after it is ordered: looking for a courier, who took it
/// and how to reach them, on the way, delivered, rate.
///
/// Before this, placing a delivery ended on a static "order accepted" page and
/// the customer had to dig through the orders tab to learn anything.
class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({
    super.key,
    required this.token,
    required this.orderId,
  });

  final String token;
  final int orderId;

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  final _api = OrderApi();

  Timer? _poll;
  Order? _order;
  String? _error;
  bool _cancelling = false;
  bool _rated = false;
  int _rating = 0;

  /// Refresh often while nobody has taken the order — that is when the
  /// customer is actually watching — then back off.
  static const _waitingTick = Duration(seconds: 4);
  static const _activeTick = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _refresh();
    _schedule(_waitingTick);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedule(Duration every) {
    _poll?.cancel();
    _poll = Timer.periodic(every, (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final order = await _api.getOrderById(
        token: widget.token,
        orderId: widget.orderId,
      );
      if (!mounted) return;
      final wasWaiting = _order?.status == 'pending';
      setState(() {
        _order = order;
        _error = null;
      });

      if (order.status == 'pending') {
        _schedule(_waitingTick);
      } else if (_isFinished(order) || order.status == 'cancelled') {
        _poll?.cancel();
      } else {
        _schedule(_activeTick);
      }

      if (wasWaiting &&
          order.status != 'pending' &&
          order.courierName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Курьер табылды: ${order.courierName}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  bool _isFinished(Order order) =>
      order.status == 'delivered' || order.status == 'completed';

  bool _isCancellable(Order order) =>
      order.status == 'pending' || order.status == 'accepted';

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заказды жокко чыгаруу'),
        content: const Text('Заказыңызды жокко чыгарасызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Жокко чыгаруу'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await _api.cancelOrder(widget.token, widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _callCourier() async {
    final phone = _order?.courierPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _rate(int stars) async {
    setState(() {
      _rating = stars;
      _rated = true;
    });
    try {
      await _api.rateCourier(
        token: widget.token,
        orderId: widget.orderId,
        rating: stars,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          _title(order),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: order == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : _errorBox(_error!),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (order.status == 'pending') _searchingCard(),
                if (order.courierName != null &&
                    !_isFinished(order) &&
                    order.status != 'cancelled')
                  _courierCard(order),
                if (_isFinished(order)) _deliveredCard(order),
                if (order.status == 'cancelled') _cancelledCard(),
                const SizedBox(height: 14),
                _routeCard(order),
                const SizedBox(height: 12),
                _detailsButton(order),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorBox(_error!),
                ],
              ],
            ),
      bottomNavigationBar: order != null && _isCancellable(order)
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _cancelling ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _cancelling
                        ? 'Жокко чыгарылууда...'
                        : 'Заказды жокко чыгаруу',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _title(Order? order) {
    switch (order?.status) {
      case 'accepted':
      case 'preparing':
      case 'ready':
        return 'Курьер табылды';
      case 'picked_up':
      case 'in_transit':
        return 'Заказ жолдо';
      case 'delivered':
      case 'completed':
        return 'Жеткирилди';
      case 'cancelled':
        return 'Жокко чыгарылды';
      default:
        return 'Курьер издөө';
    }
  }

  Widget _searchingCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          const Text(
            'Курьер изделүүдө',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Заказыңыз жакынкы курьерлерге жөнөтүлдү. '
            'Ким биринчи кабыл алса, ошол жеткирет.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _courierCard(Order order) {
    final onTheWay =
        order.status == 'picked_up' || order.status == 'in_transit';
    final vehicle = [order.courierVehicleBrand, order.courierVehicleColor]
        .where((v) => (v ?? '').trim().isNotEmpty)
        .map((v) => v!.trim())
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _transportIcon(order.courierTransport),
                  color: const Color(0xFF16A34A),
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.courierName ?? 'Курьер',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.isEmpty
                          ? _transportLabel(order.courierTransport)
                          : '${_transportLabel(order.courierTransport)} · $vehicle',
                      style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if ((order.courierVehiclePlate ?? '').trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    order.courierVehiclePlate!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: onTheWay
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  onTheWay ? Icons.navigation : Icons.inventory_2_outlined,
                  size: 18,
                  color: onTheWay
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFFC2410C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    onTheWay
                        ? 'Заказыңыз жолдо'
                        : 'Курьер заказды алууга кетти',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: onTheWay
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFC2410C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((order.courierPhone ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _callCourier,
                icon: const Icon(Icons.call, size: 19),
                label: const Text(
                  'Курьерге чалуу',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _transportIcon(String transport) {
    switch (transport) {
      case 'car':
        return Icons.directions_car;
      case 'cargo':
        return Icons.local_shipping;
      case 'scooter':
        return Icons.two_wheeler;
      default:
        return Icons.directions_walk;
    }
  }

  String _transportLabel(String transport) {
    switch (transport) {
      case 'car':
        return 'Унаа менен';
      case 'cargo':
        return 'Жүк ташуучу';
      case 'scooter':
        return 'Мотоцикл менен';
      default:
        return 'Жөө';
    }
  }

  Widget _deliveredCard(Order order) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('📦', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'Заказ жеткирилди',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (order.estimatedPrice != null) ...[
            const SizedBox(height: 4),
            Text(
              '${order.estimatedPrice!.round()} сом',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            _rated ? 'Баалооңуз үчүн рахмат!' : 'Курьерди баалаңыз',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: _rated ? null : () => _rate(star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Башкы бетке',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelledCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_outlined, size: 40, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          const Text(
            'Заказ жокко чыгарылды',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _routeRow(
            color: const Color(0xFF16A34A),
            label: 'Кайдан',
            value: order.fromAddress,
          ),
          const SizedBox(height: 12),
          _routeRow(
            color: const Color(0xFFDC2626),
            label: 'Кайда',
            value: order.toAddress,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text(
                '№${order.id}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (order.distance > 0)
                Text(
                  '${order.distance.toStringAsFixed(1)} км',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              const SizedBox(width: 12),
              if (order.estimatedPrice != null)
                Text(
                  '${order.estimatedPrice!.round()} сом',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chat, status history and the item list live on the detail page; this
  /// screen stays about what is happening right now.
  Widget _detailsButton(Order order) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(
              order: order,
              token: widget.token,
              isCourier: false,
            ),
          ),
        ),
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text(
          'Заказдын толук маалыматы',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
      ),
    );
  }
}
