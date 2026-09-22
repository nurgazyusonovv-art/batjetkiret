import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/distance_calculator.dart';
import 'package:frontend/features/profile/data/support_api.dart';
import 'package:frontend/features/taxi/data/taxi_api.dart';
import 'package:frontend/features/taxi/domain/taxi_fare.dart';
import 'package:frontend/features/taxi/presentation/taxi_address_search_page.dart';
import 'package:frontend/features/taxi/presentation/taxi_ride_page.dart';
import 'package:geolocator/geolocator.dart';

/// Ordering a city taxi: where from, where to, what it costs, order.
///
/// A self-contained flow — it shares no state or widgets with the delivery
/// order wizard.
class TaxiOrderPage extends StatefulWidget {
  const TaxiOrderPage({
    super.key,
    required this.token,
    this.initialPickup,
    this.initialPickupAddress,
  });

  final String token;
  final LatLng? initialPickup;
  final String? initialPickupAddress;

  @override
  State<TaxiOrderPage> createState() => _TaxiOrderPageState();
}

class _TaxiOrderPageState extends State<TaxiOrderPage> {
  final _api = TaxiApi();
  final _commentController = TextEditingController();

  TaxiPlace? _from;
  TaxiPlace? _to;

  AppSettings? _settings;
  TaxiFare? _fare;
  bool _measuring = false;
  bool _ordering = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPickup != null) {
      _from = TaxiPlace(
        address: (widget.initialPickupAddress ?? '').trim().isEmpty
            ? 'Учурдагы жайгашкан жер'
            : widget.initialPickupAddress!,
        location: widget.initialPickup!,
      );
    } else {
      _detectPickup();
    }
    _loadSettings();
    _resumeActiveRide();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SupportApi().getAppSettings();
      if (!mounted) return;
      setState(() => _settings = settings);
      _recalculate();
    } catch (_) {}
  }

  /// If a ride is already running, go straight to it — ordering a second taxi
  /// while sitting in one is never what the passenger meant.
  Future<void> _resumeActiveRide() async {
    final ride = await _api
        .fetchActiveRide(widget.token)
        .catchError((_) => null);
    if (!mounted || ride == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TaxiRidePage(token: widget.token, rideId: ride.id),
      ),
    );
  }

  Future<void> _detectPickup() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      final address = await RealGeocoder.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _from = TaxiPlace(
          address: address,
          location: LatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      });
      _recalculate();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPlace({required bool isFrom}) async {
    final place = await Navigator.of(context).push<TaxiPlace>(
      MaterialPageRoute(
        builder: (_) => TaxiAddressSearchPage(
          title: isFrom ? 'Кайдан алып кетели?' : 'Кайда барабыз?',
          near: _from?.location ?? widget.initialPickup,
        ),
      ),
    );
    if (place == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = place;
      } else {
        _to = place;
      }
      _error = null;
    });
    _recalculate();
  }

  Future<void> _recalculate() async {
    final from = _from;
    final to = _to;
    final settings = _settings;
    if (from == null || to == null || settings == null) return;

    setState(() {
      _measuring = true;
      _fare = null;
    });
    // Road distance, not the straight line — the same source the server bills.
    final km = await RouteDistance.calculateDrivingDistance(
      from: from.location,
      to: to.location,
    );
    if (!mounted) return;
    setState(() {
      _measuring = false;
      _fare = km == null
          ? null
          : TaxiFare.estimate(
              distanceKm: km.clamp(0.5, 500.0),
              settings: settings,
            );
    });
  }

  Future<void> _order() async {
    final from = _from;
    final to = _to;
    final fare = _fare;
    if (from == null) {
      setState(() => _error = 'Кайдан алып кетүүнү көрсөтүңүз');
      return;
    }
    if (to == null) {
      setState(() => _error = 'Кайда барууну көрсөтүңүз');
      return;
    }
    if (fare == null) {
      setState(() => _error = 'Аралык эсептелген жок, кайра аракет кылыңыз');
      return;
    }

    setState(() {
      _ordering = true;
      _error = null;
    });
    try {
      final rideId = await _api.createRide(
        token: widget.token,
        fromAddress: from.address,
        toAddress: to.address,
        fromLat: from.location.latitude,
        fromLon: from.location.longitude,
        toLat: to.location.latitude,
        toLon: to.location.longitude,
        distanceKm: fare.distanceKm,
        comment: _commentController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TaxiRidePage(token: widget.token, rideId: rideId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Такси чакыруу',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _routeCard(),
          const SizedBox(height: 14),
          _fareCard(),
          const SizedBox(height: 14),
          _commentCard(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _orderBar(),
    );
  }

  Widget _routeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _placeRow(
            dotColor: const Color(0xFF16A34A),
            label: 'Кайдан',
            value: _from?.address,
            placeholder: _locating
                ? 'Жайгашкан жериңиз аныкталып жатат...'
                : 'Алып кетүүчү жерди тандаңыз',
            onTap: () => _pickPlace(isFrom: true),
          ),
          const Divider(height: 1, indent: 46),
          _placeRow(
            dotColor: const Color(0xFFDC2626),
            label: 'Кайда',
            value: _to?.address,
            placeholder: 'Барар жериңизди тандаңыз',
            onTap: () => _pickPlace(isFrom: false),
          ),
        ],
      ),
    );
  }

  Widget _placeRow({
    required Color dotColor,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final filled = (value ?? '').trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filled ? value! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled ? AppColors.textPrimary : Colors.grey[500],
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _fareCard() {
    final fare = _fare;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_taxi_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Болжолдуу баа',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown[400],
                  ),
                ),
                const SizedBox(height: 2),
                if (_measuring)
                  const Text(
                    'Эсептелүүдө...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  )
                else if (fare == null)
                  Text(
                    'Эки даректи тандаңыз',
                    style: TextStyle(fontSize: 14, color: Colors.brown[400]),
                  )
                else
                  Text(
                    '${fare.priceLabel}  ·  ${fare.distanceLabel}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                if (fare != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Айдоочуга накталай төлөнөт'
                    '${fare.serviceFee > 0 ? ' · ${fare.serviceFee.round()} сом сервис акысы' : ''}',
                    style: TextStyle(fontSize: 11.5, color: Colors.brown[400]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 2,
        maxLength: 200,
        style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Айдоочуга эскертүү (мисалы: көк дарбаза, 2 жүргүнчү)',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  Widget _orderBar() {
    final ready = _from != null && _to != null && _fare != null && !_measuring;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: ready && !_ordering ? _order : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent4,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _ordering
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _fare == null
                      ? 'Такси чакыруу'
                      : 'Такси чакыруу · ${_fare!.priceLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
