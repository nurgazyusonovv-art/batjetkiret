import 'package:flutter/material.dart';

/// Shown in place of a map when the build carries no 2GIS key.
///
/// MapGL's own failure is an English sentence on a blank beige canvas, which
/// reads like a broken map rather than a missing `--dart-define`. This says
/// what actually went wrong, in the language the app is written in.
class MapKeyMissingView extends StatelessWidget {
  const MapKeyMissingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F1EC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 44, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              const Text(
                'Карта ачкычы жок',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Бул билд TWOGIS_API_KEY сыз чогултулган.\n'
                'Иштетүү үчүн ./run.sh,\n'
                'релиз үчүн ./build_ios.sh же ./build_android.sh\n'
                'колдонуңуз.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
