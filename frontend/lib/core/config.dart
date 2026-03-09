import 'package:flutter/foundation.dart';

class AppConfig {
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

  // Yandex API key for geocoding and routing
  static const String _envYandexApiKey = String.fromEnvironment(
    'YANDEX_API_KEY',
    defaultValue: '815b5065-2f27-4e69-aab3-45df9fed1bda',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != '0.0.0.0') {
        return 'http://$host:8000';
      }
      return 'http://localhost:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // For Android emulator use special gateway IP
      return 'http://10.0.2.2:8000';
    }

    // For iOS simulator, try localhost first, then fallback to host IP
    // The simulator should be able to reach localhost if properly configured
    return 'http://localhost:8000';
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
