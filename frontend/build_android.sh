#!/bin/bash

# Android APK Build Script with Yandex Maps API Key

set -e

cd "$(dirname "$0")"

echo "📦 Android Build with Yandex Maps"
echo "=================================="

# Check .gradle files
if [ ! -f "android/local.properties" ]; then
    echo "❌ Error: android/local.properties not found!"
    echo "Please run setup first"
    exit 1
fi

echo "✅ android/local.properties found"

# Check .env
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found - using android/local.properties"
fi

# Load from .env if available
if [ -f ".env" ]; then
    source .env
    api_key_flag="--dart-define=YANDEX_API_KEY=$YANDEX_API_KEY"
fi

echo ""
echo "Select build type:"
echo "1. Development APK (debug) - DEFAULT"
echo "2. Profile APK (performance testing)"
echo "3. Release APK (production)"

read -p "Select build type [1-3]: " build_choice

case $build_choice in
    2)
        build_cmd="flutter build apk --profile"
        build_type="Profile"
        ;;
    3)
        build_cmd="flutter build apk --release"
        build_type="Release"
        ;;
    *)
        build_cmd="flutter build apk"
        build_type="Debug"
        ;;
esac

echo ""
echo "🔨 Building $build_type APK..."
echo "API configuration: android/local.properties"
echo ""

# Build APK - gradle will automatically read from android/local.properties
$build_cmd $api_key_flag

echo ""
echo "✅ Build complete!"
echo ""

# Find APK
if [ "$build_type" = "Release" ]; then
    apk_path="build/app/outputs/flutter-apk/app-release.apk"
elif [ "$build_type" = "Profile" ]; then
    apk_path="build/app/outputs/flutter-apk/app-profile.apk"
else
    apk_path="build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ -f "$apk_path" ]; then
    echo "📍 APK location: $apk_path"
    echo ""
    echo "To install on device/emulator:"
    echo "  adb install $apk_path"
    echo ""
    echo "Or:"
    echo "  flutter install"
else
    echo "APK build location may vary - check build/ directory"
fi
