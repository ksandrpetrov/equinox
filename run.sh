#!/bin/sh
#
# run.sh — build and launch equinox.
#
# There is only one build: production (Release). This mirrors the app that
# ships to users, so what you run locally behaves like the real thing.

set -e

. "$(dirname "$0")/scripts/require-arm64.sh"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# Always run from the project root (directory of this script).
cd "$(dirname "$0")"

DERIVED_DATA="build/DerivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/equinox.app"
BRIDGE_PATH="${DERIVED_DATA}/Build/Products/Release/equinox-bridge"

echo "${GREEN}Building equinox (Release)...${NC}"
xcodebuild \
    -project equinox.xcodeproj \
    -scheme equinox \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build

if [ ! -d "${APP_PATH}" ]; then
    echo "${RED}Build did not produce ${APP_PATH}${NC}"
    exit 1
fi

if [ ! -x "${BRIDGE_PATH}" ]; then
    echo "${GREEN}Building equinox-bridge (Release)...${NC}"
    xcodebuild \
        -project equinox.xcodeproj \
        -scheme equinox-bridge \
        -configuration Release \
        -derivedDataPath "${DERIVED_DATA}" \
        build
fi

if [ ! -f "mcp/dist/server.js" ]; then
    echo "${YELLOW}MCP server not built. Building MCP stack...${NC}"
    ./scripts/build-mcp.sh
fi

echo "${GREEN}Launching equinox...${NC}"
pkill -x equinox 2>/dev/null || true
sleep 1
open "${APP_PATH}"

echo "${GREEN}Done.${NC} equinox is a menu bar app — look for its icon in the menu bar."
