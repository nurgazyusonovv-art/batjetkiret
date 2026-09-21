#!/bin/bash
# iOS запуск без debugger - обходит Flutter 3.41.4 + Xcode 26.2 несовместимость

set -e

echo "🏗️  Собираем приложение для iOS (debug)..."
cd "$(dirname "$0")/frontend"

# Чистим кэш
flutter clean 2>/dev/null || true
flutter pub get

# Собираем для iOS
echo "⏳ Компиляция..."
flutter build ios --simulator --debug 2>&1 | grep -E "error|warning|Building|Prov|✨"

# Получаем параметры
BUNDLE_ID="com.batkenexpress.app"
APP_PATH="./build/ios/iphonesimulator/Runner.app"
DEVICE_ID="booted"

echo "📱 Установка приложения на симулятор..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH" 2>&1 | tail -3 || true

echo "🚀 Запуск приложения..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" 

echo ""
echo "✅ Приложение запущено!"
echo ""
echo "📋 Полезные команды:"
echo "  - Логи:     xcrun simctl spawn booted log stream --predicate 'processImagePath contains \"Runner\"'"
echo "  - Убить:    xcrun simctl terminate $DEVICE_ID $BUNDLE_ID"
echo "  - Удалить:  xcrun simctl uninstall $DEVICE_ID $BUNDLE_ID"
echo ""
