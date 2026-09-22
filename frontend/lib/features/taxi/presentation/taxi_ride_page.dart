import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/taxi/data/taxi_api.dart';
import 'package:frontend/features/taxi/data/taxi_ride.dart';
import 'package:url_launcher/url_launcher.dart';

/// The live ride: one screen that follows the order from "looking for a
/// driver" through to rating, because that is one continuous thing for the
/// passenger — not four separate screens to get lost between.
class TaxiRidePage extends StatefulWidget {
  const TaxiRidePage({super.key, required this.token, required this.rideId});

  final String token;
  final int rideId;

  @override
  State<TaxiRidePage> createState() => _TaxiRidePageState();
}

class _TaxiRidePageState extends State<TaxiRidePage> {
  final _api = TaxiApi();

  Timer? _poll;
  TaxiRide? _ride;
  String? _error;
  bool _cancelling = false;
  bool _rated = false;
  int _rating = 0;

  /// While waiting for a driver the passenger stares at the screen, so refresh
  /// quickly; once someone is driving, slow down to save battery and data.
  static const _fastTick = Duration(seconds: 3);
  static const _slowTick = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _refresh();
    _schedule(_fastTick);
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
      final ride = await _api.fetchRide(
        token: widget.token,
        rideId: widget.rideId,
      );
      if (!mounted) return;
      final wasSearching = _ride?.phase == TaxiRidePhase.searching;
      setState(() {
        _ride = ride;
        _error = null;
      });

      if (ride.phase == TaxiRidePhase.searching) {
        _schedule(_fastTick);
      } else if (ride.phase == TaxiRidePhase.finished ||
          ride.phase == TaxiRidePhase.cancelled) {
        _poll?.cancel();
      } else {
        _schedule(_slowTick);
      }

      if (wasSearching && ride.phase == TaxiRidePhase.driverOnTheWay) {
        _announceDriver(ride);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _announceDriver(TaxiRide ride) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text(
          'Айдоочу табылды: ${ride.driverName ?? ''} — ${ride.carLabel}',
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заказды жокко чыгаруу'),
        content: const Text('Такси заказыңызды жокко чыгарасызбы?'),
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
      await _api.cancelRide(token: widget.token, rideId: widget.rideId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _callDriver() async {
    final phone = _ride?.driverPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _submitRating(int stars) async {
    setState(() {
      _rating = stars;
      _rated = true;
    });
    await _api.rateDriver(
      token: widget.token,
      rideId: widget.rideId,
      rating: stars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          _titleFor(ride?.phase),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ride == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : _errorBox(_error!),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (ride.phase == TaxiRidePhase.searching) _searchingCard(),
                if (ride.hasDriver &&
                    (ride.phase == TaxiRidePhase.driverOnTheWay ||
                        ride.phase == TaxiRidePhase.inRide))
                  _driverCard(ride),
                if (ride.phase == TaxiRidePhase.finished) _finishedCard(ride),
                if (ride.phase == TaxiRidePhase.cancelled) _cancelledCard(),
                const SizedBox(height: 14),
                _routeCard(ride),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorBox(_error!),
                ],
              ],
            ),
      bottomNavigationBar: ride != null && ride.isCancellable
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

  String _titleFor(TaxiRidePhase? phase) {
    switch (phase) {
      case TaxiRidePhase.driverOnTheWay:
        return 'Айдоочу жолдо';
      case TaxiRidePhase.inRide:
        return 'Сапарда';
      case TaxiRidePhase.finished:
        return 'Сапар бүттү';
      case TaxiRidePhase.cancelled:
        return 'Жокко чыгарылды';
      case TaxiRidePhase.searching:
      case null:
        return 'Айдоочу издөө';
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
            'Жакынкы айдоочулар изделүүдө',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Заказыңыз жаныңыздагы айдоочуларга жөнөтүлдү. '
            'Ким биринчи кабыл алса, ошол келет.',
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

  Widget _driverCard(TaxiRide ride) {
    final onTheWay = ride.phase == TaxiRidePhase.driverOnTheWay;
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
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF16A34A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.driverName ?? 'Айдоочу',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.carLabel,
                      style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if ((ride.carPlate ?? '').trim().isNotEmpty)
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
                    ride.carPlate!.toUpperCase(),
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
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  onTheWay ? Icons.directions_car : Icons.navigation,
                  size: 18,
                  color: onTheWay
                      ? const Color(0xFFC2410C)
                      : const Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    onTheWay
                        ? 'Айдоочу сизге келип жатат'
                        : 'Барар жериңизге кетип жатасыз',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: onTheWay
                          ? const Color(0xFFC2410C)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((ride.driverPhone ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _callDriver,
                icon: const Icon(Icons.call, size: 19),
                label: const Text(
                  'Айдоочуга чалуу',
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

  Widget _finishedCard(TaxiRide ride) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'Сапар бүттү',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ride.price.round()} сом',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _rated ? 'Баалооңуз үчүн рахмат!' : 'Айдоочуну баалаңыз',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: _rated ? null : () => _submitRating(star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Жабуу',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeCard(TaxiRide ride) {
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
            value: ride.fromAddress,
          ),
          const SizedBox(height: 12),
          _routeRow(
            color: const Color(0xFFDC2626),
            label: 'Кайда',
            value: ride.toAddress,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text(
                '№${ride.id}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (ride.distanceKm > 0)
                Text(
                  '${ride.distanceKm.toStringAsFixed(1)} км',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              const SizedBox(width: 12),
              Text(
                '${ride.price.round()} сом',
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
