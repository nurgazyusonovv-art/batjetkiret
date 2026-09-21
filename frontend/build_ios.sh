#!/bin/bash

# iOS Build Script with Yandex Maps API Key

set -e

cd "$(dirname "$0")"

echo "📱 iOS Build with Yandex Maps"
echo "=============================="

# Check .env
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "API key must be passed manually"
fi

# Load from .env if available
if [ -f ".env" ]; then
    source .env
    api_key_flag="--dart-define=YANDEX_API_KEY=$YANDEX_API_KEY"
    # Routing / address search keys (optional — the app falls back gracefully)
    [ -n "$TWOGIS_API_KEY" ] && api_key_flag="$api_key_flag --dart-define=TWOGIS_API_KEY=$TWOGIS_API_KEY"
    [ -n "$ORS_API_KEY" ] && api_key_flag="$api_key_flag --dart-define=ORS_API_KEY=$ORS_API_KEY"
    [ -n "$OSRM_BASE_URL" ] && api_key_flag="$api_key_flag --dart-define=OSRM_BASE_URL=$OSRM_BASE_URL"
    echo "✅ API keys loaded from .env"
else
    read -p "Enter YANDEX_API_KEY: " api_key
    api_key_flag="--dart-define=YANDEX_API_KEY=$api_key"
fi

echo ""
echo "Select build type:"
echo "1. iOS App (for physical device)"
echo "2. iOS Simulator (for testing)"

read -p "Select build type [1-2]: " build_choice

case $build_choice in
    1)
        build_cmd="flutter build ios"
        build_type="Physical Device"
        ;;
    *)
        build_cmd="flutter build ios --simulator"
        build_type="Simulator"
        ;;
esac

echo ""
echo "🔨 Building for $build_type..."
echo ""

$build_cmd $api_key_flag

echo ""
echo "✅ Build complete!"
echo ""

if [ "$build_type" = "Simulator" ]; then
    echo "To run on simulator:"
    echo "  flutter run -d <simulator_id>"
    echo ""
    echo "List available simulators:"
    echo "  xcrun simctl list devices"
else
    echo "Follow these steps:"
    echo "1. Open Xcode: open ios/Runner.xcworkspace"
    echo "2. Select physical device"
    echo "3. Click 'Play' to install and run"
fi
