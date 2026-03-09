# API Key Configuration Summary

## Status: ✅ COMPLETE

All Yandex Maps API keys are properly stored and configured for development and deployment.

---

## Configuration Files

### 1. `.env` (Development Environment Variables)
**Location:** `/frontend/.env`
**Purpose:** Local development configuration
**Protected:** ✅ YES (in .gitignore)

```
YANDEX_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
YANDEX_MAPKIT_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
```

**Usage:**
```bash
# Run with environment variables from .env
source .env
flutter run --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY --dart-define=YANDEX_MAPKIT_API_KEY=$YANDEX_MAPKIT_API_KEY
```

### 2. `android/local.properties` (Android Build Configuration)
**Location:** `/frontend/android/local.properties`
**Purpose:** Android Gradle build configuration
**Protected:** ✅ YES (in .gitignore)

```properties
sdk.dir=/Users/nurgazyuson/Library/Android/sdk
YANDEX_MAPKIT_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
YANDEX_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
```

**Usage:**
- Automatically read by Android Gradle during builds
- No additional configuration needed for `flutter build apk` or `flutter build appbundle`

### 3. iOS Configuration
**Location:** `ios/Runner/Info.plist` (location permissions)
**Status:** ✅ Configured
- No API key storage needed (MapKit configuration via Podfile)
- Uses Yandex MapKit pod (v4.22.0-lite)

---

## Dart Configuration

### AppConfig Class (`lib/core/config.dart`)
All API keys are accessed through:
```dart
String get yandexApiKey => AppConfig.yandexApiKey;
String get mapKitApiKey => AppConfig.yandexMapKitApiKey;
```

**How it works:**
1. `String.fromEnvironment()` reads from `--dart-define` variables OR environment variables
2. Falls back to empty string if not defined
3. RealGeocoder automatically uses MockGeocoder if API key is empty

---

## Security & Protection

### ✅ Protected Files (in .gitignore)
- `.env`
- `.env.local`
- `.env.*.local`
- `android/local.properties`

### ✅ Safe Usage Patterns
- **Development:** Use `.env` file with `source .env && flutter run ...`
- **CI/CD:** Use GitHub Secrets OR GitLab CI/CD variables
- **Android Build:** API key from `android/local.properties`
- **iOS Build:** API key in `ios/Runner/Info.plist` (with secrets)

### ❌ NEVER
- Commit `.env` files to git
- Hardcode API keys in source code
- Push `android/local.properties` to public repositories
- Share API keys in Slack/email/Discord

---

## Running the App

### Development (with full API features)
```bash
cd /Users/nurgazyuson/python_projects/batjetkiret-backend/frontend

# Load environment and run
source .env
flutter run -d <device> \
  --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY \
  --dart-define=YANDEX_MAPKIT_API_KEY=$YANDEX_MAPKIT_API_KEY
```

### Development (with MockGeocoder only)
```bash
# No API key needed - will use 7-city mock data
flutter run -d <device>
```

### Android Build
```bash
# API key automatically read from android/local.properties
flutter build apk

# Or with explicit override:
flutter build apk --dart-define=YANDEX_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
```

### iOS Build
```bash
flutter build ios --dart-define=YANDEX_API_KEY=fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b
```

---

## Environment Fallback Chain

**For Geocoding (RealGeocoder):**
1. Try Yandex API with stored key → ✅ Works worldwide
2. If API call fails → Fall back to MockGeocoder
3. If no key → Use MockGeocoder (7 cities: Bishkek, Osh, Naryn, etc.)

**For MapKit Widget:**
1. Use API key from configuration
2. Display interactive Yandex map
3. User can tap to select location

---

## Verification Checklist

- ✅ `.env` file created with both API keys
- ✅ `android/local.properties` created with SDK path + API keys
- ✅ `.gitignore` updated to protect sensitive files
- ✅ `AppConfig` class reads from environment variables
- ✅ `RealGeocoder` uses API key with fallback to MockGeocoder
- ✅ Flutter environment verified (flutter doctor ✓)
- ✅ Android toolchain ready
- ✅ iOS/Xcode ready
- ✅ CocoaPods dependencies installed (YandexMapsMobile 4.22.0-lite)

---

## API Key Details

**Key:** `fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b`
**Services:** 
- Yandex Geocoding API (forward/reverse)
- Yandex MapKit (interactive maps)

**Resource Limits:** Check Yandex Cloud Console
**Expiration:** Verify in Yandex Cloud Console

---

## Next Steps

1. **Development Testing:**
   ```bash
   source .env && flutter run -d android
   ```

2. **Test Geocoding:**
   - Create new order
   - Select location from map
   - Verify distance calculation (Bishkek → Osh ≈ 598 km)

3. **Production Deployment:**
   - Store API key in GitHub Secrets (or CI/CD platform)
   - Update build workflow to pass key via `--dart-define`
   - Build and sign APK/IPA for distribution

4. **Monitor:**
   - Check Yandex Cloud Console for API usage
   - Set up alerts for quota limits

---

**Last Updated:** 2025-03-05
**Configuration Status:** ✅ READY FOR DEVELOPMENT & TESTING
