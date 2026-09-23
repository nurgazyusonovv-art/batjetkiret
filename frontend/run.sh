#!/bin/bash

# Run the app on a device or simulator with the map/geocoder keys.
#
# Plain `flutter run` (and the Run button in Xcode) passes no --dart-define, so
# the app starts with an empty TWOGIS_API_KEY and every map renders as 2GIS's
# "Your MapGL key is invalid" screen. Use this instead.
#
#   ./run.sh              # pick a device interactively
#   ./run.sh <device-id>  # e.g. ./run.sh E81474AE-9FD1-4485-AC5E-6BF26C7C5396

set -e

cd "$(dirname "$0")"

if [ ! -f ".env" ]; then
    echo "❌ .env файлы жок. .env.example дан көчүрүп, ачкычтарды коюңуз."
    exit 1
fi

set -a
source .env
set +a

if [ -z "$TWOGIS_API_KEY" ]; then
    echo "❌ TWOGIS_API_KEY .env файлында жок — карта иштебей калат."
    echo "   .env ичине кошуңуз: TWOGIS_API_KEY=<ачкыч>"
    exit 1
fi

defines="--dart-define=TWOGIS_API_KEY=$TWOGIS_API_KEY"
[ -n "$ORS_API_KEY" ] && defines="$defines --dart-define=ORS_API_KEY=$ORS_API_KEY"
[ -n "$OSRM_BASE_URL" ] && defines="$defines --dart-define=OSRM_BASE_URL=$OSRM_BASE_URL"
[ -n "$YANDEX_API_KEY" ] && defines="$defines --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY"
[ -n "$API_BASE_URL" ] && defines="$defines --dart-define=API_BASE_URL=$API_BASE_URL"

echo "✅ Ачкычтар .env файлынан жүктөлдү"

if [ -n "$1" ]; then
    exec flutter run -d "$1" $defines
else
    exec flutter run $defines
fi
