#!/bin/bash

# Flutter build script with configurable refresh intervals
# Usage: ./build_flutter.sh [profile]
# Profiles: dev, test, staging, production

PROFILE=${1:-dev}

case "$PROFILE" in
  dev)
    echo "Building for Development (fast refresh)..."
    flutter run \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=5 \
      --dart-define=REFRESH_HOME_IDLE_INTERVAL=15 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=5 \
      --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=12 \
      --dart-define=REFRESH_PROFILE_INTERVAL=30 \
      --dart-define=REFRESH_MAX_BACKOFF_MINUTES=1
    ;;

  test)
    echo "Building for Testing (medium refresh)..."
    flutter build apk --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=3 \
      --dart-define=REFRESH_HOME_IDLE_INTERVAL=10 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=3 \
      --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=10 \
      --dart-define=REFRESH_PROFILE_INTERVAL=15 \
      --dart-define=REFRESH_MAX_BACKOFF_MINUTES=1
    ;;

  staging)
    echo "Building for Staging (balanced refresh)..."
    flutter build apk --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8 \
      --dart-define=REFRESH_HOME_IDLE_INTERVAL=20 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8 \
      --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15 \
      --dart-define=REFRESH_PROFILE_INTERVAL=60 \
      --dart-define=REFRESH_MAX_BACKOFF_MINUTES=2
    ;;

  production)
    echo "Building for Production (optimized refresh)..."
    flutter build apk --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15 \
      --dart-define=REFRESH_HOME_IDLE_INTERVAL=30 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15 \
      --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=30 \
      --dart-define=REFRESH_PROFILE_INTERVAL=120 \
      --dart-define=REFRESH_MAX_BACKOFF_MINUTES=5
    ;;

  ios-dev)
    echo "Building iOS for Development..."
    flutter run -d <iOS_DEVICE_ID> \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=5 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=5 \
      --dart-define=REFRESH_PROFILE_INTERVAL=30
    ;;

  ios-prod)
    echo "Building iOS for Production..."
    flutter build ios --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15 \
      --dart-define=REFRESH_PROFILE_INTERVAL=120
    ;;

  web)
    echo "Building Web..."
    flutter build web --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=10 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=10 \
      --dart-define=REFRESH_PROFILE_INTERVAL=45
    ;;

  *)
    echo "Usage: ./build_flutter.sh [profile]"
    echo ""
    echo "Available profiles:"
    echo "  dev         - Development mode (flutter run with fast refresh)"
    echo "  test        - Testing build with medium intervals"
    echo "  staging     - Staging build with balanced intervals"
    echo "  production  - Production build with optimized intervals"
    echo "  ios-dev     - iOS development build"
    echo "  ios-prod    - iOS production build"
    echo "  web         - Web production build"
    exit 1
    ;;
esac
