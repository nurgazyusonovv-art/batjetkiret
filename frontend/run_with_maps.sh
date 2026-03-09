#!/bin/bash

# Yandex Maps Development Runner
# Quick script to run Flutter with API keys configured

set -e

cd "$(dirname "$0")"

echo "📱 Yandex Maps API Configuration"
echo "================================="

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file with:"
    echo "  YANDEX_API_KEY=your_key_here"
    echo "  YANDEX_MAPKIT_API_KEY=your_key_here"
    exit 1
fi

# Load environment variables
echo "✅ Loading API keys from .env"
source .env

# Verify keys
if [ -z "$YANDEX_API_KEY" ] || [ -z "$YANDEX_MAPKIT_API_KEY" ]; then
    echo "❌ Error: API keys not found in .env file!"
    exit 1
fi

echo "✅ API keys loaded"
echo ""
echo "Select device (or press Enter for default):"
echo "1. Android emulator/device (default)"
echo "2. iOS simulator/device"
echo "3. macOS"

read -p "Select device [1-3]: " device_choice

case $device_choice in
    2)
        device_flag="-d ios"
        ;;
    3)
        device_flag="-d macos"
        ;;
    *)
        device_flag="-d android"
        ;;
esac

echo ""
echo "🚀 Starting Flutter app with Yandex Maps configuration..."
echo "Device: $device_flag"
echo ""

# Run Flutter with API keys
flutter run $device_flag \
    --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY \
    --dart-define=YANDEX_MAPKIT_API_KEY=$YANDEX_MAPKIT_API_KEY
