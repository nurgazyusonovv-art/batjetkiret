import 'package:flutter/material.dart';
import '../../../core/utils/distance_calculator.dart';
import 'map_picker.dart';

/// Compact map location selector — shows selected address info and opens
/// full MapPickerWidget on tap. No embedded WebView to avoid platform issues.
class CompactMapPreview extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final Function(LatLng, String) onLocationChanged;
  final String? label;

  const CompactMapPreview({
    super.key,
    this.initialLocation,
    this.initialAddress,
    required this.onLocationChanged,
    this.label = 'Жайгашкан жерин тандаңыз',
  });

  @override
  State<CompactMapPreview> createState() => _CompactMapPreviewState();
}

class _CompactMapPreviewState extends State<CompactMapPreview> {
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;
  }

  Future<void> _openFullMap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MapPickerWidget(
          initialLocation: _selectedLocation,
          initialAddress: _selectedAddress,
          title: widget.label,
          onLocationSelected: (location, address) {},
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;
      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
      });
      widget.onLocationChanged(location, address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _selectedLocation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],

        GestureDetector(
          onTap: _openFullMap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasLocation ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLocation ? Colors.blue.shade300 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasLocation ? Colors.blue : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLocation
                            ? (_selectedAddress ?? 'Адрес белгисиз')
                            : 'Адрес тандалган жок',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasLocation
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        hasLocation ? 'Өзгөрт' : 'Тандоо',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
