import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/orders/data/order_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExternalTripType {
  delivery('delivery', 'Жеткирип берүү', Icons.delivery_dining_rounded),
  taxi('taxi', 'Такси', Icons.local_taxi_rounded);

  const ExternalTripType(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;
}

class ExternalTripTrackerPage extends StatefulWidget {
  const ExternalTripTrackerPage({
    super.key,
    required this.token,
    required this.tripType,
    this.orderId,
    this.customerPhone,
    this.fromAddress,
    this.toAddress,
  });

  final String token;
  final ExternalTripType tripType;
  final int? orderId;
  final String? customerPhone;
  final String? fromAddress;
  final String? toAddress;

  static const _sessionActiveKey = 'external_trip.active';
  static const _sessionTypeKey = 'external_trip.type';
  static const _sessionStartedAtKey = 'external_trip.started_at';
  static const _sessionDistanceKey = 'external_trip.distance_km';
  static const _sessionTotalPriceKey = 'external_trip.total_price';
  static const _sessionLastLatKey = 'external_trip.last_lat';
  static const _sessionLastLonKey = 'external_trip.last_lon';
  static const _sessionOrderIdKey = 'external_trip.order_id';

  static Future<ExternalTripType?> activeTripType() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_sessionActiveKey) ?? false)) return null;
    final value = prefs.getString(_sessionTypeKey);
    return ExternalTripType.values.cast<ExternalTripType?>().firstWhere(
      (type) => type?.apiValue == value,
      orElse: () => null,
    );
  }

  static Future<int?> activeOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_sessionActiveKey) ?? false)) return null;
    return prefs.getInt(_sessionOrderIdKey);
  }

  @override
  State<ExternalTripTrackerPage> createState() =>
      _ExternalTripTrackerPageState();
}

class _ExternalTripTrackerPageState extends State<ExternalTripTrackerPage>
    with WidgetsBindingObserver {
  final _api = OrderApi();
  StreamSubscription<Position>? _positionSub;
  double? _lastLat;
  double? _lastLon;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  Timer? _clockTimer;

  bool _isTracking = false;
  bool _isQuoting = false;
  bool _isFinishing = false;
  String? _error;
  double _distanceKm = 0;
  double _totalPrice = 0;
  double _commission = 0;
  Map<String, dynamic>? _lastQuote;

  bool get _isFinished => _finishedAt != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isTracking) {
      _catchUpFromCurrentPosition().then((_) => _refreshQuote());
    }
  }

  Future<void> _restoreActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final active =
        prefs.getBool(ExternalTripTrackerPage._sessionActiveKey) ?? false;
    final type = prefs.getString(ExternalTripTrackerPage._sessionTypeKey);
    final storedOrderId = prefs.getInt(
      ExternalTripTrackerPage._sessionOrderIdKey,
    );
    if (!active ||
        type != widget.tripType.apiValue ||
        storedOrderId != widget.orderId) {
      return;
    }

    final startedAtMs = prefs.getInt(
      ExternalTripTrackerPage._sessionStartedAtKey,
    );
    if (!mounted || startedAtMs == null) return;

    setState(() {
      _startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
      _distanceKm =
          prefs.getDouble(ExternalTripTrackerPage._sessionDistanceKey) ?? 0;
      _totalPrice =
          prefs.getDouble(ExternalTripTrackerPage._sessionTotalPriceKey) ?? 0;
      _lastLat = prefs.getDouble(ExternalTripTrackerPage._sessionLastLatKey);
      _lastLon = prefs.getDouble(ExternalTripTrackerPage._sessionLastLonKey);
      _finishedAt = null;
      _isTracking = true;
      _error = null;
    });
    _startClock();
    if (await _ensureLocationPermission(silent: true)) {
      await _catchUpFromCurrentPosition();
      await _refreshQuote();
      _listenToPositions();
    }
  }

  Future<void> _persistActiveSession() async {
    final start = _startedAt;
    if (start == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ExternalTripTrackerPage._sessionActiveKey, true);
    await prefs.setString(
      ExternalTripTrackerPage._sessionTypeKey,
      widget.tripType.apiValue,
    );
    if (widget.orderId != null) {
      await prefs.setInt(
        ExternalTripTrackerPage._sessionOrderIdKey,
        widget.orderId!,
      );
    } else {
      await prefs.remove(ExternalTripTrackerPage._sessionOrderIdKey);
    }
    await prefs.setInt(
      ExternalTripTrackerPage._sessionStartedAtKey,
      start.millisecondsSinceEpoch,
    );
    await prefs.setDouble(
      ExternalTripTrackerPage._sessionDistanceKey,
      _distanceKm,
    );
    await prefs.setDouble(
      ExternalTripTrackerPage._sessionTotalPriceKey,
      _totalPrice,
    );
    if (_lastLat != null && _lastLon != null) {
      await prefs.setDouble(
        ExternalTripTrackerPage._sessionLastLatKey,
        _lastLat!,
      );
      await prefs.setDouble(
        ExternalTripTrackerPage._sessionLastLonKey,
        _lastLon!,
      );
    }
  }

  Future<void> _clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ExternalTripTrackerPage._sessionActiveKey);
    await prefs.remove(ExternalTripTrackerPage._sessionTypeKey);
    await prefs.remove(ExternalTripTrackerPage._sessionStartedAtKey);
    await prefs.remove(ExternalTripTrackerPage._sessionDistanceKey);
    await prefs.remove(ExternalTripTrackerPage._sessionTotalPriceKey);
    await prefs.remove(ExternalTripTrackerPage._sessionLastLatKey);
    await prefs.remove(ExternalTripTrackerPage._sessionLastLonKey);
    await prefs.remove(ExternalTripTrackerPage._sessionOrderIdKey);
  }

  Future<bool> _ensureLocationPermission({bool silent = false}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!silent) {
        setState(() => _error = 'Геолокация өчүк. GPS/Location күйгүзүңүз.');
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!silent) {
        setState(
          () => _error = 'Километр эсептөө үчүн геолокация уруксаты керек.',
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    if (_isTracking) return;
    setState(() {
      _error = null;
      _distanceKm = 0;
      _totalPrice = 0;
      _lastQuote = null;
      _lastLat = null;
      _lastLon = null;
      _finishedAt = null;
    });

    if (!await _ensureLocationPermission()) return;

    try {
      final initial = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (widget.orderId != null) {
        await _api.startDelivery(widget.token, widget.orderId!);
      }
      if (!mounted) return;
      setState(() {
        _lastLat = initial.latitude;
        _lastLon = initial.longitude;
        _startedAt = DateTime.now();
        _isTracking = true;
      });
      _startClock();
      await _refreshQuote();
      await _persistActiveSession();
      _listenToPositions();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  void _listenToPositions() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 15,
          ),
        ).listen(
          _onPosition,
          onError: (e) {
            if (mounted) setState(() => _error = 'GPS окууда ката: $e');
          },
        );
  }

  Future<void> _catchUpFromCurrentPosition() async {
    try {
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      await _addPosition(current);
    } catch (_) {}
  }

  Future<void> _onPosition(Position pos) async {
    await _addPosition(pos);
    await _refreshQuote();
  }

  Future<void> _addPosition(Position pos) async {
    final prevLat = _lastLat;
    final prevLon = _lastLon;
    if (prevLat == null || prevLon == null) {
      setState(() {
        _lastLat = pos.latitude;
        _lastLon = pos.longitude;
      });
      await _persistActiveSession();
      return;
    }

    final meters = Geolocator.distanceBetween(
      prevLat,
      prevLon,
      pos.latitude,
      pos.longitude,
    );
    if (meters < 3 || meters > 1000) {
      setState(() {
        _lastLat = pos.latitude;
        _lastLon = pos.longitude;
      });
      await _persistActiveSession();
      return;
    }

    setState(() {
      _distanceKm += meters / 1000;
      _lastLat = pos.latitude;
      _lastLon = pos.longitude;
    });
    await _persistActiveSession();
  }

  Future<void> _refreshQuote() async {
    if (_isQuoting) return;
    setState(() => _isQuoting = true);
    try {
      final quote = await _api.quoteExternalTrip(
        token: widget.token,
        orderType: widget.tripType.apiValue,
        distanceKm: _distanceKm,
      );
      if (!mounted) return;
      setState(() {
        _lastQuote = quote;
        _totalPrice = ((quote['total_price'] as num?) ?? 0).toDouble();
        _commission = ((quote['courier_commission'] as num?) ?? 0).toDouble();
        _error = null;
      });
      await _persistActiveSession();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isQuoting = false);
    }
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() {
      _isFinishing = true;
      _error = null;
    });
    await _catchUpFromCurrentPosition();
    await _positionSub?.cancel();
    _positionSub = null;
    _clockTimer?.cancel();
    await _refreshQuote();
    if (!mounted) return;
    try {
      if (widget.orderId != null) {
        final result = await _api.completeExternalOrder(
          token: widget.token,
          orderId: widget.orderId!,
          distanceKm: _distanceKm,
        );
        _distanceKm = ((result['distance_km'] as num?) ?? _distanceKm)
            .toDouble();
        _totalPrice = ((result['total_price'] as num?) ?? _totalPrice)
            .toDouble();
        _commission = ((result['courier_commission'] as num?) ?? _commission)
            .toDouble();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFinishing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _startClock();
      _listenToPositions();
      return;
    }
    final finishedAt = DateTime.now();
    setState(() {
      _isTracking = false;
      _isFinishing = false;
      _finishedAt = finishedAt;
    });
    await _clearActiveSession();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExternalTripResultPage(
          tripType: widget.tripType,
          distanceKm: _distanceKm,
          totalPrice: _totalPrice,
          commission: _commission,
          durationText: _durationText,
          isOrderLinked: widget.orderId != null,
        ),
      ),
    );
  }

  String get _durationText {
    final start = _startedAt;
    if (start == null) return '00:00';
    final end = _finishedAt ?? DateTime.now();
    final d = end.difference(start);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final quote = _lastQuote;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.tripType.label),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(),
            if (widget.orderId != null) ...[
              const SizedBox(height: 12),
              _orderCard(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    Icons.route_rounded,
                    'Километр',
                    '${_distanceKm.toStringAsFixed(2)} км',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    Icons.timer_outlined,
                    'Убакыт',
                    _durationText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _priceCard(quote),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isFinishing
                  ? null
                  : _isTracking
                  ? _finish
                  : _isFinished && widget.orderId != null
                  ? () =>
                        Navigator.of(context).popUntil((route) => route.isFirst)
                  : _start,
              icon: _isFinishing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isTracking
                          ? Icons.check_circle
                          : _isFinished && widget.orderId != null
                          ? Icons.home_outlined
                          : Icons.play_arrow,
                    ),
              label: Text(
                _isFinishing
                    ? 'Аякталууда...'
                    : _isTracking
                    ? 'Жеткирилди'
                    : _isFinished && widget.orderId != null
                    ? 'Башкы бетке'
                    : _isFinished
                    ? 'Кайра баштоо'
                    : 'Баштоо',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking
                    ? const Color(0xFF16A34A)
                    : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.tripType.icon,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTracking
                      ? 'Километр эсептелип жатат'
                      : _isFinished
                      ? 'Сапар аяктады'
                      : 'Сырткы заказ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Тариф backend настройкадан алынат',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard() {
    final route = [
      widget.fromAddress,
      widget.toAddress,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' → ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Системадан тышкары заказ #${widget.orderId}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF166534),
            ),
          ),
          if (route.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(route, style: const TextStyle(color: AppColors.textPrimary)),
          ],
          if (widget.customerPhone?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'Кардар: ${widget.customerPhone}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCard(Map<String, dynamic>? quote) {
    final base = ((quote?['base_price'] as num?) ?? 0).toDouble();
    final perKm = ((quote?['price_per_km'] as num?) ?? 0).toDouble();
    final extraAfter = ((quote?['extra_after_km'] as num?) ?? 0).toDouble();
    final extraPerKm = ((quote?['extra_price_per_km'] as num?) ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Төлөм',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_isQuoting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_totalPrice.toStringAsFixed(0)} сом',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          _formulaLine('Башкы баа', '${base.toStringAsFixed(0)} сом'),
          _formulaLine('1 км баа', '${perKm.toStringAsFixed(0)} сом/км'),
          if (extraPerKm > 0)
            _formulaLine(
              '${extraAfter.toStringAsFixed(0)} км ашса',
              '+${extraPerKm.toStringAsFixed(0)} сом/км',
            ),
          if (widget.orderId != null)
            _formulaLine(
              'Сервис комиссиясы (2%)',
              '${_commission.toStringAsFixed(0)} сом',
            ),
        ],
      ),
    );
  }

  Widget _formulaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class ExternalTripResultPage extends StatelessWidget {
  const ExternalTripResultPage({
    super.key,
    required this.tripType,
    required this.distanceKm,
    required this.totalPrice,
    required this.commission,
    required this.durationText,
    this.isOrderLinked = false,
  });

  final ExternalTripType tripType;
  final double distanceKm;
  final double totalPrice;
  final double commission;
  final String durationText;
  final bool isOrderLinked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Результат'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 54,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Ийгиликтүү аяктады',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tripType.label,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _resultRow(
                          Icons.payments_rounded,
                          'Жалпы сумма',
                          '${totalPrice.toStringAsFixed(0)} сом',
                        ),
                        if (isOrderLinked)
                          _resultRow(
                            Icons.percent_rounded,
                            'Сервис комиссиясы',
                            '${commission.toStringAsFixed(0)} сом',
                          ),
                        _resultRow(
                          Icons.timer_outlined,
                          'Убакыт',
                          durationText,
                        ),
                        _resultRow(
                          Icons.route_rounded,
                          'Километр',
                          '${distanceKm.toStringAsFixed(2)} км',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isOrderLinked
                      ? () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst)
                      : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(isOrderLinked ? 'Башкы бетке' : 'Жаңы эсептөө'),
                ),
              ),
              if (!isOrderLinked) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: const Text(
                      'Башкы бетке',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
