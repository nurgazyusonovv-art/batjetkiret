# iOS Yandex Maps Configuration Guide

## Prerequisites
- macOS with Xcode 12+
- iOS deployment target 11.0 or higher
- CocoaPods package manager
- Yandex MapKit API key from [yandex.cloud.ru](https://yandex.cloud.ru)
- Flutter iOS environment configured

## Step 1: Update ios/Podfile

Edit `ios/Podfile`:

```ruby
# Podfile
platform :ios, '11.0'

# ...existing code...

target 'Runner' do
  flutter_root = File.expand_path(File.join(packages_dir, 'flutter'))
  load File.join(flutter_root, 'packages', 'flutter_tools', 'bin', 'podhelper.rb')

  flutter_ios_podfile_setup

  # Yandex MapKit Pod
  # Version 4.3.0 or higher required
  pod 'YandexMapKitDirect', '~> 4.3.0'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      
      # Fix deployment target for pods
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'PERMISSION_LOCATION=1',
        ]
        # Ensure iOS 11.0 minimum
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end
end
```

## Step 2: Update ios/Runner/Info.plist

Edit `ios/Runner/Info.plist` - add location permission strings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ...existing keys... -->

    <!-- Location Permissions (Required for Maps and Distance Calculation) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Батжеткирет ордерин түзүү үчүн сизиндин жайгашкан жеринги керек анын үчүн локациялык рукса керек</string>

    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>Батжеткирет фондо жатканда дагы андан сизиндин локацияны табыш керек</string>

    <key>NSLocationAlwaysUsageDescription</key>
    <string>Батжеткирет фондо жатканда дагы сизиндин жайгашкан жерин кайра табышым керек</string>

    <!-- Yandex Maps Permissions (Optional, for some features) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Картасынан скриншот жасоо үчүн сүрөт нөмүнөсүнө чыгуу керек</string>

    <!-- Application Can Only Work With WiFi (Optional, remove if not needed) -->
    <!-- <key>NSLocalNetworkUsageDescription</key>
    <string>Local network access is needed for location services</string> -->

    <!-- ...rest of existing keys... -->
</dict>
</plist>
```

### Edit Info.plist using Command Line

If you prefer not to edit XML directly:

```bash
# Using plutil (macOS)
plutil -insert NSLocationWhenInUseUsageDescription -string "Батжеткирет ордерин түзүү үчүн сизиндин жайгашкан жеринги керек" ios/Runner/Info.plist

plutil -insert NSLocationAlwaysAndWhenInUseUsageDescription -string "Батжеткирет фондо жатканда дагы сизиндин локацияны табыш керек" ios/Runner/Info.plist

plutil -insert NSLocationAlwaysUsageDescription -string "Батжеткирет фондо жатканда дагы сизиндин жайгашкан жерин кайра табышым керек" ios/Runner/Info.plist
```

## Step 3: RunnerBuildPhase Script (Handle Embedded Pod)

Some versions of YandexMapKit require additional build phase configuration:

1. Open `Runner.xcworkspace` (NOT `Runner.xcodeproj`) in Xcode:
```bash
open ios/Runner.xcworkspace
```

2. Select **Runner** → **Build Phases**
3. Check that **Pods** framework is linked in **Link Binary With Libraries**
4. If not, add it via the **+** button in **Link Binary With Libraries**

## Step 4: Update Minimum Deployment Target

```bash
# Ensure pods deployed to iOS 11.0 minimum
sed -i '' 's/platform :ios.*/platform :ios, "11.0"/' ios/Podfile

# Or manually edit ios/Podfile:
# Change: platform :ios, '11.0'
```

## Step 5: Install Dependencies

```bash
# Navigate to iOS directory
cd ios

# Install or update pods
pod install --repo-update

# If pod install fails, try:
pod repo update
pod install

# Return to project root
cd ..
```

## Step 6: Flutter Configuration for iOS

Ensure flutter iOS configuration is ready:

```bash
# Clean Flutter build
flutter clean

# Get dependencies (including yandex_mapkit)
flutter pub get

# Check iOS setup
flutter doctor -v | grep -A 5 "ios"
```

## Step 7: Build and Test

### Development Build (Debug)

```bash
# Option 1: Direct run
flutter run -d iphone
# or for simulator: flutter run -d "iPhone 14"

# Option 2: With API keys
flutter run -d iphone \
  --dart-define=YANDEX_API_KEY=your_dev_key \
  --dart-define=YANDEX_MAPKIT_API_KEY=your_dev_key
```

### Release Build

```bash
flutter build ios \
  --dart-define=YANDEX_API_KEY=your_prod_key \
  --dart-define=YANDEX_MAPKIT_API_KEY=your_prod_key \
  --release
```

### Using Xcode Directly (Advanced)

```bash
# Build via Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Runner" scheme
# 2. Select target device or simulator
# 3. Press Cmd+B to build
# 4. Press Cmd+R to run
```

## Step 8: Handle Location Permissions at Runtime

The `geolocator` package handles iOS permission requests automatically, but ensure Info.plist strings are user-friendly.

Create `lib/core/utils/location_permissions.dart`:

```dart
import 'package:geolocator/geolocator.dart';

class LocationPermissions {
  /// Request location permission for iOS
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse || 
             result == LocationPermission.always;
    }
    
    if (permission == LocationPermission.deniedForever) {
      // On iOS, must open app settings
      await Geolocator.openLocationSettings();
      return false;
    }
    
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  /// Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // iOS needs more time
      );
    } catch (e) {
      print('Error getting iOS location: $e');
      return null;
    }
  }
}
```

## Troubleshooting

### Error: "Pod install fails with YandexMapKit"

**Solution:** Update Podfile platform and repo:

```bash
# Update repo
pod repo update

# Clean and reinstall
rm -rf ios/Pods ios/Podfile.lock
pod install
```

### Error: "Cannot find YandexMapKit"

**Cause:** Pod not installed or incompatible version

**Solution:**
```bash
# Check pod version
pod search YandexMapKit

# Update Podfile to specific version:
# pod 'YandexMapKitDirect', '4.3.0'

pod install --repo-update
```

### Error: "Minimum deployment target 11.0 required"

**Solution:** Update `ios/Podfile`:
```ruby
platform :ios, '11.0'  # Change from older versions
```

### Error: "Location permission not requested on iOS"

**Cause:** Missing or incorrect Info.plist strings

**Solution:**
1. Open `ios/Runner/Info.plist` in Xcode
2. Add all three location permission keys
3. Ensure strings are descriptive (shown to user)
4. Rebuild: `flutter clean && flutter pub get`

### Error: "YandexMapKit version too old"

**Solution:** Update Podfile and reinstall:
```ruby
pod 'YandexMapKitDirect', '~> 4.3.0'  # Use latest 4.3.x
```

Then:
```bash
pod install --repo-update
flutter clean
flutter pub get
```

### Build Fails with "Undefined symbols"

**Cause:** Missing linked frameworks

**Solution:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to **Runner** → **Build Phases** → **Link Binary With Libraries**
3. Ensure these are present:
   - YandexMapKit.framework
   - SystemConfiguration.framework
   - Security.framework
4. If missing, add via **+** button

### Simulator Performance (Maps Lag)

**Workaround:** Use physical device or higher-spec simulator:
```bash
# Create higher-spec simulator
xcrun simctl create high-perf "iPhone 14 Pro" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-14-pro

# Run on new simulator
flutter run -d high-perf
```

## Environment Variables for CI/CD

### GitHub Actions Example

```yaml
name: Build iOS

on:
  push:
    branches: [ main, staging ]

jobs:
  build:
    runs-on: macos-latest
    
    env:
      YANDEX_API_KEY: ${{ secrets.YANDEX_API_KEY }}
      YANDEX_MAPKIT_API_KEY: ${{ secrets.YANDEX_MAPKIT_API_KEY }}
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - run: flutter pub get
      
      - run: flutter build ios --release \
          --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY \
          --dart-define=YANDEX_MAPKIT_API_KEY=$YANDEX_MAPKIT_API_KEY
```

## Summary Checklist

- [ ] Podfile platform set to iOS 11.0+
- [ ] YandexMapKitDirect pod added to Podfile
- [ ] pod install completed successfully
- [ ] Info.plist has all 3 location permission keys
- [ ] Deployment target in Xcode is 11.0+
- [ ] geolocator package integrated

- [ ] Yandex API keys obtained
- [ ] No hardcoded API keys (use --dart-define)
- [ ] flutter pub get completed
- [ ] flutter run works on simulator/device
- [ ] Distance calculation works (test Bishkek → Osh)
- [ ] Location permission dialog appears on first run
- [ ] Test build succeeds: flutter build ios --release

## Next Steps

1. **Test on Real Device:**
   ```bash
   flutter run -d <device_id>
   ```

2. **Create MapPicker Widget** (after platform setup complete)

3. **Implement RealGeocoder** with production API keys

4. **Set Up TestFlight** for beta testing

## See Also

- [Android Configuration](ANDROID_YANDEX_MAPS_CONFIG.md)
- [Yandex Maps Integration Guide](YANDEX_MAPS_INTEGRATION.md)
- [Geolocator Package Docs](https://pub.dev/packages/geolocator)
- [Yandex MapKit iOS Docs](https://yandex.com/dev/maps/mapkit/)
