import 'package:flutter/foundation.dart';

class AppConfig {
  static const String productionBaseUrl =
      'https://batjetkiret-production.up.railway.app';

  // You can override with: flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Refresh interval configuration (seconds)
  // Default values for MVP; override with --dart-define in production
  static const String _envHomeActiveInterval = String.fromEnvironment(
    'REFRESH_HOME_ACTIVE_INTERVAL',
    defaultValue: '5',
  );

  static const String _envHomeIdleInterval = String.fromEnvironment(
    'REFRESH_HOME_IDLE_INTERVAL',
    defaultValue: '15',
  );

  static const String _envOrdersActiveInterval = String.fromEnvironment(
    'REFRESH_ORDERS_ACTIVE_INTERVAL',
    defaultValue: '5',
  );

  static const String _envOrdersIdleInterval = String.fromEnvironment(
    'REFRESH_ORDERS_IDLE_INTERVAL',
    defaultValue: '12',
  );

  static const String _envProfileInterval = String.fromEnvironment(
    'REFRESH_PROFILE_INTERVAL',
    defaultValue: '30',
  );

  static const String _envMaxBackoffMinutes = String.fromEnvironment(
    'REFRESH_MAX_BACKOFF_MINUTES',
    defaultValue: '1',
  );

  // Google Maps API keys (if needed for web)
  static const String _envGoogleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // Yandex API key for geocoding and routing.
  // Pass at build time: --dart-define=YANDEX_API_KEY=<key>
  static const String _envYandexApiKey = String.fromEnvironment(
    'YANDEX_API_KEY',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return '/api';
    // Default to production for both release and debug builds on real devices.
    // Override with --dart-define=API_BASE_URL=http://10.0.2.2:8000 for emulator.
    return productionBaseUrl;
  }

  static String? mediaUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:')) {
      return raw;
    }
    if (kIsWeb && raw.startsWith('/api/')) {
      return raw;
    }
    if (!kIsWeb && raw.startsWith('/api/media/proxy')) {
      return '$productionBaseUrl${raw.replaceFirst('/api', '')}';
    }
    if (raw.startsWith('https://') && raw.contains('.r2.dev/')) {
      final encoded = Uri.encodeComponent(raw);
      if (kIsWeb) return '/api/media/proxy?url=$encoded';
      return '$productionBaseUrl/media/proxy?url=$encoded';
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$productionBaseUrl$raw';
    return '$productionBaseUrl/$raw';
  }

  static Duration get homeActiveInterval {
    final seconds = int.tryParse(_envHomeActiveInterval) ?? 5;
    return Duration(seconds: seconds);
  }

  static Duration get homeIdleInterval {
    final seconds = int.tryParse(_envHomeIdleInterval) ?? 15;
    return Duration(seconds: seconds);
  }

  static Duration get ordersActiveInterval {
    final seconds = int.tryParse(_envOrdersActiveInterval) ?? 5;
    return Duration(seconds: seconds);
  }

  static Duration get ordersIdleInterval {
    final seconds = int.tryParse(_envOrdersIdleInterval) ?? 12;
    return Duration(seconds: seconds);
  }

  static Duration get profileInterval {
    final seconds = int.tryParse(_envProfileInterval) ?? 30;
    return Duration(seconds: seconds);
  }

  static Duration get maxBackoffInterval {
    final minutes = int.tryParse(_envMaxBackoffMinutes) ?? 1;
    return Duration(minutes: minutes);
  }

  static String get yandexApiKey => _envYandexApiKey;

  static String get yandexMapKitApiKey => '';

  static String get googleMapsApiKey => _envGoogleMapsApiKey;

  static const String networkErrorMessage =
      'Серверге туташуу болбой жатат. Backend иштеп жатканын текшериңиз. API URL-и: ';
}
