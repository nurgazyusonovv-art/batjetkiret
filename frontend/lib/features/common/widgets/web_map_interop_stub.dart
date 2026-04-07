import 'package:flutter/material.dart';

/// Stub for non-web platforms — never actually used since kIsWeb guards it.
Widget buildWebMapView({
  required double initialLat,
  required double initialLon,
  required void Function(double lat, double lon) onTap,
}) =>
    const SizedBox.shrink();

void disposeWebMapListener() {}
