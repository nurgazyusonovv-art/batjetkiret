# Android Yandex Maps Configuration Guide

## Prerequisites
- Android API level 21+ (minSdkVersion)
- Yandex MapKit API key from [yandex.cloud.ru](https://yandex.cloud.ru)
- Flutter Android environment configured

## Step 1: Get Yandex MapKit API Key

1. Go to [Yandex Cloud Console](https://console.cloud.yandex.ru/)
2. Create or select a project
3. Go to **Services** → **Map API**
4. Create API key (keep it secure)
5. Or use Yandex Geocoding API key from Step 1 of YANDEX_MAPS_INTEGRATION.md

## Step 2: Update AndroidManifest.xml

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.batjetkiret.app">

    <!-- Location Permissions for Maps and Distance Calculation -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">

        <!-- Yandex MapKit API Key (maps widget) -->
        <meta-data
            android:name="com.yandex.mapkit.API_KEY"
            android:value="YOUR_YANDEX_MAPKIT_API_KEY_HERE" />

        <!-- Optional: Yandex Geocoding API for reverse geocoding -->
        <meta-data
            android:name="com.yandex.geocoding.API_KEY"
            android:value="YOUR_YANDEX_GEOCODING_API_KEY_HERE" />

        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Define any other custom activity or service here if needed -->

    </application>
</manifest>
```

### Replace API Keys

```bash
# Option 1: Direct replacement in file
sed -i 's/YOUR_YANDEX_MAPKIT_API_KEY_HERE/your_actual_key_here/g' android/app/src/main/AndroidManifest.xml

# Option 2: Using Flutter build parameters (recommended)
# See Step 4 below
```

## Step 3: Update android/app/build.gradle

Edit `android/app/build.gradle`:

```gradle
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterSdkPath = localProperties.getProperty('flutter.sdk')
if (flutterSdkPath == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterSdkPath/packages/flutter_tools/gradle/flutter.gradle"

android {
    compileSdkVersion 33

    ndkVersion "25.1.8937393"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.batjetkiret.app"
        // IMPORTANT: minSdkVersion must be 21 or higher for Yandex MapKit
        minSdkVersion 21
        targetSdkVersion 33
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    // Yandex MapKit native library
    implementation 'com.yandex.android:maps.mobile:4.2.0-full'
}
```

## Step 4: Using Flutter Build Parameters (Recommended for CI/CD)

Instead of hardcoding API keys, use Flutter `--dart-define` flags:

### Development Build
```bash
flutter run \
  --dart-define=YANDEX_MAPKIT_API_KEY=your_dev_key_here \
  --dart-define=YANDEX_API_KEY=your_geocoding_dev_key_here \
  -d emulator
```

### Release Build
```bash
flutter build apk \
  --dart-define=YANDEX_MAPKIT_API_KEY=your_prod_key_here \
  --dart-define=YANDEX_API_KEY=your_geocoding_prod_key_here \
  --release
```

### Using Bash Script (build_flutter.sh)

Update existing `build_flutter.sh`:

```bash
#!/bin/bash

# ... existing code ...

case "$FLAVOR" in
    dev)
        echo "🛠  Building for Development..."
        YANDEX_MAPKIT_KEY="dev_mapkit_key_from_env"
        YANDEX_API_KEY="dev_geocoding_key_from_env"
        ;;
    test)
        echo "🧪 Building for Testing..."
        YANDEX_MAPKIT_KEY="test_mapkit_key_from_env"
        YANDEX_API_KEY="test_geocoding_key_from_env"
        ;;
    staging)
        echo "📦 Building for Staging..."
        YANDEX_MAPKIT_KEY="staging_mapkit_key_from_env"
        YANDEX_API_KEY="staging_geocoding_key_from_env"
        ;;
    production)
        echo "🚀 Building for Production..."
        YANDEX_MAPKIT_KEY="prod_mapkit_key_from_env"
        YANDEX_API_KEY="prod_geocoding_key_from_env"
        ;;
esac

flutter build apk \
  --dart-define=YANDEX_MAPKIT_API_KEY="$YANDEX_MAPKIT_KEY" \
  --dart-define=YANDEX_API_KEY="$YANDEX_API_KEY" \
  --release \
  --split-per-abi
```

## Step 5: Location Permissions at Runtime

Add to `lib/core/utils/location_permissions.dart`:

```dart
import 'package:geolocator/geolocator.dart';

class LocationPermissions {
  /// Request location permission and check status
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse || 
             result == LocationPermission.always;
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Open app settings
      await Geolocator.openLocationSettings();
      return false;
    }
    
    return true;
  }

  /// Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
}
```

## Step 6: Verify Android Build

### Test Build
```bash
# Check gradle configuration
./gradlew :app:assembleDebug --stacktrace

# Or with Dart defines
flutter build apk --debug \
  --dart-define=YANDEX_MAPKIT_API_KEY=test_key \
  --dart-define=YANDEX_API_KEY=test_key
```

### Release Build
```bash
./gradlew :app:assembleRelease --stacktrace

# Or with Flutter (recommended)
flutter build apk --release \
  --dart-define=YANDEX_MAPKIT_API_KEY=prod_key \
  --dart-define=YANDEX_API_KEY=prod_key
```

## Troubleshooting

### Error: "Yandex MapKit initialization failed"
- **Cause:** Missing or invalid API key in AndroidManifest.xml
- **Solution:** Verify API key is correctly set in meta-data

### Error: "ACCESS_FINE_LOCATION permission denied"
- **Cause:** Permissions not declared or not granted by user
- **Solution:** 
  - Verify permissions in AndroidManifest.xml
  - Ensure geolocator package handles runtime permissions
  - Test on Android 6.0+ (requires runtime permission request)

### Error: "Minimum SDK version is 19, got 16"
- **Cause:** minSdkVersion too low
- **Solution:** Update to minSdkVersion 21 in build.gradle

### Error: "INTERNET permission required"
- **Cause:** Network permission not set
- **Solution:** Add `<uses-permission android:name="android.permission.INTERNET" />` to AndroidManifest.xml

### Build Size Too Large
- **Cause:** MapKit library includes all map tiles
- **Solution:** Use APK splitting by ABI or enable ProGuard minification

```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Testing Android Configuration

### 1. Test with Mock Geocoder (No API Key)
```bash
flutter run -d emulator
# App will use MockGeocoder - works with predefined cities
```

### 2. Test with Yandex API
```bash
flutter run -d emulator \
  --dart-define=YANDEX_API_KEY=your_actual_key
# App will use RealGeocoder with Yandex API
```

### 3. Test Distance Calculation
1. Go to order creation
2. Select "Бишкек" as from address (or any city in MockGeocoder)
3. Select "Ош" as to address
4. Distance should calculate as ~598 km

## Environment Variables for CI/CD

Set in GitHub Actions / GitLab CI environment:

```yaml
# .github/workflows/build.yml
env:
  YANDEX_MAPKIT_API_KEY: ${{ secrets.YANDEX_MAPKIT_API_KEY }}
  YANDEX_API_KEY: ${{ secrets.YANDEX_API_KEY }}
```

Then use in build step:
```bash
flutter build apk --release \
  --dart-define=YANDEX_MAPKIT_API_KEY=$YANDEX_MAPKIT_API_KEY \
  --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY
```

## Summary Checklist

- [ ] Yandex API keys obtained from yandex.cloud.ru
- [ ] AndroidManifest.xml updated with meta-data tags
- [ ] build.gradle minSdkVersion set to 21+
- [ ] Location permissions added to AndroidManifest.xml
- [ ] No hardcoded API keys (use --dart-define instead)
- [ ] geolocator package configured for location
- [ ] Test build succeeds: `flutter build apk --debug`
- [ ] Distance calculation working (test with Bishkek → Osh)
- [ ] Location permissions working (test at runtime)

## Next: iOS Configuration

See `IOS_YANDEX_MAPS_CONFIG.md` for iPhone/iPad setup.
