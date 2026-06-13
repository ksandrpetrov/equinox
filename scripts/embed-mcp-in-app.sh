#!/bin/sh
#
# embed-mcp-in-app.sh — copy MCP server and equinox-bridge into equinox.app Resources.
# Invoked from the equinox Xcode target (Run Script phase).

set -e

cd "${SRCROOT}"

RESOURCES="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources"
MCP_DST="${RESOURCES}/mcp"
BRIDGE_SRC="${BUILT_PRODUCTS_DIR}/equinox-bridge"
BRIDGE_DST="${RESOURCES}/equinox-bridge"

if [ ! -f "mcp/dist/server.js" ]; then
    echo "warning: mcp/dist/server.js not found — run ./scripts/build-mcp.sh to embed MCP in the app"
    exit 0
fi

mkdir -p "${MCP_DST}"
rsync -a --delete mcp/dist/ "${MCP_DST}/dist/"
if [ -d "mcp/node_modules" ]; then
    rsync -a mcp/node_modules/ "${MCP_DST}/node_modules/"
fi

if [ -x "${BRIDGE_SRC}" ]; then
    cp "${BRIDGE_SRC}" "${BRIDGE_DST}"
    chmod +x "${BRIDGE_DST}"
else
    echo "warning: equinox-bridge not built — MCP bridge will not be embedded"
fi
