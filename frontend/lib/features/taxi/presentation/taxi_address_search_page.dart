import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/utils/distance_calculator.dart';
import 'package:frontend/features/common/widgets/map_picker.dart';
import 'package:geolocator/geolocator.dart';

/// A place the passenger picked: text the driver can read plus exact coordinates.
class TaxiPlace {
  const TaxiPlace({required this.address, required this.location});

  final String address;
  final LatLng location;
}

/// Full-screen address picker for a ride.
///
/// Search runs through RealGeocoder, so it is 2GIS first — the only source with
/// Batken's house numbers.
class TaxiAddressSearchPage extends StatefulWidget {
  const TaxiAddressSearchPage({
    super.key,
    required this.title,
    this.hint = 'Көчө жана үй номери (мис. Токтогул 44)',
    this.near,
    this.allowMyLocation = true,
  });

  final String title;
  final String hint;

  /// Bias for search results — the passenger's own position when known.
  final LatLng? near;
  final bool allowMyLocation;

  @override
  State<TaxiAddressSearchPage> createState() => _TaxiAddressSearchPageState();
}

class _TaxiAddressSearchPageState extends State<TaxiAddressSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<AddressSuggestion> _results = const [];
  bool _searching = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    final found = await RealGeocoder.searchAddresses(query, near: widget.near);
    // A slower earlier request must not overwrite newer results.
    if (!mounted || id != _requestId) return;
    setState(() {
      _results = found;
      _searching = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _toast('GPS уруксаты берилген жок');
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
      _pick(
        TaxiPlace(
          address: address,
          location: LatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _toast('Жайгашкан жерди аныктоо мүмкүн болбоду');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    // The picker reports its pick through the callback, but it is still the
    // top route at that moment — popping here would close the picker and drop
    // the address. Remember it, and close this page once the picker is gone.
    TaxiPlace? picked;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapPickerWidget(
          initialLocation: widget.near,
          title: widget.title,
          onLocationSelected: (location, address) {
            picked = TaxiPlace(address: address, location: location);
          },
        ),
      ),
    );
    if (picked != null) _pick(picked!);
  }

  void _pick(TaxiPlace place) {
    if (!mounted) return;
    Navigator.of(context).pop(place);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search, size: 21),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 19),
                          onPressed: _controller.clear,
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          if (widget.allowMyLocation)
            _actionRow(
              icon: Icons.my_location,
              label: 'Менин учурдагы ордум',
              busy: _locating,
              onTap: _useMyLocation,
            ),
          _actionRow(
            icon: Icons.map_outlined,
            label: 'Картадан тандоо',
            onTap: _pickOnMap,
          ),
          const Divider(height: 20),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return ListTile(
      onTap: busy ? null : onTap,
      leading: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().length < 3) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Көчөнүн атын жаза бериңиз — мисалы «Раззаков» же «Токтогул 44»',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Дарек табылган жок',
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final item = _results[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined, color: AppColors.primary),
          title: Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
          onTap: () => _pick(
            TaxiPlace(address: item.fullAddress, location: item.location),
          ),
        );
      },
    );
  }
}
