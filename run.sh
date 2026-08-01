#!/bin/bash
#
# run.sh — build and launch equinox.
#
# There is only one build: production (Release). This mirrors the app that
# ships to users, so what you run locally behaves like the real thing.

set -e

. "$(dirname "$0")/scripts/require-arm64.sh"
. "$(dirname "$0")/scripts/xcodebuild-local-settings.sh"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Always run from the project root (directory of this script).
cd "$(dirname "$0")"
load_xcodebuild_local_settings "Local.xcconfig"

DERIVED_DATA="build/DerivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/equinox.app"

echo "${GREEN}Building equinox (Release)...${NC}"
xcodebuild \
    -project equinox.xcodeproj \
    -scheme equinox \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build \
    "${XCODEBUILD_LOCAL_SETTINGS[@]}"

if [ ! -d "${APP_PATH}" ]; then
    echo "${RED}Build did not produce ${APP_PATH}${NC}"
    exit 1
fi

echo "${GREEN}Launching equinox...${NC}"
pkill -x equinox 2>/dev/null || true
sleep 1
open "${APP_PATH}"

echo "${GREEN}Done.${NC} equinox is a menu bar app — look for its icon in the menu bar."
