#!/bin/bash
#
# build-mcp.sh — build equinox-bridge and the TypeScript MCP server.

set -e

. "$(dirname "$0")/require-arm64.sh"
. "$(dirname "$0")/xcodebuild-local-settings.sh"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

cd "$(dirname "$0")/.."
load_xcodebuild_local_settings "Local.xcconfig"

echo "${GREEN}Generating MCP tool-name list...${NC}"
./scripts/gen-mcp-tool-names.sh

DERIVED_DATA="build/DerivedData"
BRIDGE_PATH="${DERIVED_DATA}/Build/Products/Release/equinox-bridge"

echo "${GREEN}Building equinox-bridge (Release)...${NC}"
xcodebuild \
    -project equinox.xcodeproj \
    -scheme equinox-bridge \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    build \
    "${XCODEBUILD_LOCAL_SETTINGS[@]}"

if [ ! -x "${BRIDGE_PATH}" ]; then
    echo "${RED}Build did not produce ${BRIDGE_PATH}${NC}"
    exit 1
fi

echo "${GREEN}Building MCP server...${NC}"
cd mcp
npm install
npm run build
npm test

echo "${GREEN}Done.${NC}"
echo "Bridge: ${BRIDGE_PATH}"
echo "MCP:    mcp/dist/server.js"
echo "Cursor: enable equinox-calendar from .cursor/mcp.json"
