# 🗺️ Yandex Maps Integration - Quick Start Guide

## Status: ✅ READY FOR DEVELOPMENT

All API keys are configured and the system is ready for testing with Yandex Maps integration.

---

## 📋 What's Configured

✅ **API Keys Stored:**
- `.env` - Development environment variables
- `android/local.properties` - Android build configuration
- Both protected in `.gitignore`

✅ **Flutter Configuration:**
- `AppConfig` class reads API keys from environment
- Yandex Geocoding integration ready
- MapPicker widget for location selection

✅ **Platform Setup:**
- **Android:** Minimum SDK 21, manifests configured
- **iOS:** Deployment target 12.0, CocoaPods installed (YandexMapsMobile 4.22.0-lite)

✅ **Distance Calculation:**
- Haversine formula implemented
- MockGeocoder with 7 Kyrgyzstan cities (for fallback)
- RealGeocoder with Yandex API (with automatic fallback)

---

## 🚀 Quick Start (3 Steps)

### Step 1: Verify Setup
```bash
cd frontend

# Check .env file
cat .env

# Check Android configuration
cat android/local.properties
```

### Step 2: Run Development App
```bash
# For Android emulator/device
./run_with_maps.sh
# Select option 1 (Android) when prompted

# OR for iOS simulator
./run_with_maps.sh
# Select option 2 (iOS) when prompted
```

### Step 3: Test Map Features
In the app:
1. Create a new order
2. Look for "Select Location" button
3. Tap to open MapPicker
4. Tap on desired location
5. Confirm selection
6. Distance will be calculated automatically (Bishkek→Osh ≈ 598 km)

---

## 🛠️ Development Commands

### Run with Yandex Maps (Full features)
```bash
source .env && flutter run --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY
```

### Run with Mock Geocoder (Device offline, 7 cities only)
```bash
flutter run
# Automatically uses MockGeocoder for Bishkek, Osh, Naryn, etc.
```

### Build Android APK
```bash
./build_android.sh
# Select build type (Debug/Profile/Release)
```

### Build iOS IPA
```bash
./build_ios.sh
# Select build type (Device/Simulator)
```

### Check Code Quality
```bash
flutter analyze     # Check for issues
flutter test        # Run unit tests (if defined)
```

---

## 📂 Key File Locations

| File | Purpose | Status |
|------|---------|--------|
| `.env` | API key storage (dev) | ✅ Created |
| `android/local.properties` | Android build config | ✅ Created |
| `lib/core/config.dart` | App configuration | ✅ Ready |
| `lib/core/utils/distance_calculator.dart` | Distance & geocoding | ✅ Ready |
| `lib/features/common/widgets/map_picker.dart` | Map selection UI | ✅ Ready |
| `android/app/src/main/AndroidManifest.xml` | Android permissions | ✅ Ready |
| `ios/Podfile` | iOS dependencies | ✅ Ready |

---

## 🔑 API Key Details

**Current Key:** `fadf7cd3-e43d-4b7b-9aa5-664b5f108b6b`

**Services Enabled:**
- ✅ Yandex Geocoding API - Address ↔ Coordinates
- ✅ Yandex MapKit - Interactive maps

**Check Usage:**
Go to [Yandex Cloud Console](https://console.cloud.yandex.ru/) → Quotas & Usage

---

## 🧪 Testing Scenarios

### Scenario 1: Mock Geocoder (Offline)
```bash
flutter run
# Limited to 7 Kyrgyzstan cities
# No API calls needed
```

### Scenario 2: Real Yandex API (Online)
```bash
source .env
flutter run --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY
# Works worldwide
# Real-time geocoding
```

### Scenario 3: Distance Calculation
1. Order from Bishkek, KG
2. Order to Osh, KG
3. Expected: ~598 km
4. Actual: (check order details)

---

## 🐛 Troubleshooting

### "API key is empty"
**Problem:** App using MockGeocoder instead of real API
**Solution:** 
```bash
source .env
flutter run --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY
```

### "Network error"
**Problem:** API call failed (no internet, quota exceeded)
**Fallback:** App automatically uses MockGeocoder
**Check:** Yandex Cloud Console for quota status

### Map widget not displaying
**Problem:** Yandex MapKit not initialized
**Solution:**
- ✅ Android: Check `AndroidManifest.xml` has API key meta-data
- ✅ iOS: Check CocoaPods installed (`flutter pub get`)

### Build fails on Android
**Problem:** Missing SDK or API key in gradle
**Check:**
```bash
cat android/local.properties
# Should have sdk.dir and YANDEX_MAPKIT_API_KEY
```

---

## 🚢 Deployment Checklist

- [ ] API key working with RealGeocoder
- [ ] MapPicker widget tested and working
- [ ] Distance calculation verified (Bishkek→Osh)
- [ ] Android APK built and tested
- [ ] iOS IPA built and tested
- [ ] `.env` NOT committed to git
- [ ] `android/local.properties` NOT committed to git
- [ ] API key stored in CI/CD secrets (GitHub/GitLab)
- [ ] Production build passes all tests

---

## 📱 Device Support

| Platform | Status | Min Version | Notes |
|----------|--------|-------------|-------|
| Android | ✅ Ready | 5.0 (SDK 21) | Full support |
| iOS | ✅ Ready | 12.0+ | Full support |
| Web | ⚠️ Not tested | Chrome 90+ | May need adaptation |
| macOS | ✅ Ready | 10.13+ | Desktop testing only |

---

## 📚 Documentation

- **API Key Config:** [API_KEY_CONFIG_SUMMARY.md](API_KEY_CONFIG_SUMMARY.md)
- **Yandex Maps Setup:** [YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md)
- **Android Config:** [../ANDROID_YANDEX_MAPS_CONFIG.md](../ANDROID_YANDEX_MAPS_CONFIG.md)
- **iOS Config:** [../IOS_YANDEX_MAPS_CONFIG.md](../IOS_YANDEX_MAPS_CONFIG.md)

---

## ✨ Features Implemented

### ✅ Rating System
- 5-star rating dialogs
- Save ratings to backend
- Display in user/courier profile
- Auto-refresh with adaptive intervals

### ✅ Distance Calculation
- Haversine formula
- Automatic coordinate conversion
- Fallback from API to mock data

### ✅ Location Selection
- Interactive Yandex Map widget
- Quick city buttons
- Address reverse-geocoding
- Tap-to-select location

### ✅ Order Enhancement
- Distance in order creation
- Distance display in order details
- Courier distance calculation

---

## 📞 Support

**Issues?** Check:
1. Is `.env` present with correct keys?
2. Is `android/local.properties` present?
3. Run `flutter doctor` - all items ✓?
4. Run `flutter analyze` - no errors?
5. Check Yandex Cloud Console - API active?

---

**Last Updated:** 2025-03-05
**Ready for:** Development, Testing, Deployment
