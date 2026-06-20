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

find_npm() {
    if command -v npm >/dev/null 2>&1; then
        command -v npm
        return 0
    fi

    for candidate in \
        "/opt/homebrew/bin/npm" \
        "/usr/local/bin/npm" \
        "/opt/local/bin/npm" \
        "${HOME}/.volta/bin/npm" \
        "${HOME}/.asdf/shims/npm"
    do
        if [ -x "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done

    for candidate in "${HOME}"/.nvm/versions/node/*/bin/npm
    do
        if [ -x "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

if [ ! -f "mcp/dist/server.js" ]; then
    echo "warning: mcp/dist/server.js not found — run ./scripts/build-mcp.sh to embed MCP in the app"
    exit 0
fi

mkdir -p "${MCP_DST}"
rsync -a --delete mcp/dist/ "${MCP_DST}/dist/"
cp mcp/package.json mcp/package-lock.json "${MCP_DST}/"

if [ -d "mcp/node_modules" ]; then
    rsync -a --delete mcp/node_modules/ "${MCP_DST}/node_modules/"
    NPM_BIN="$(find_npm)" || {
        echo "error: npm not found. Install Node.js or run Xcode with npm on PATH so MCP runtime dependencies can be pruned for signing."
        exit 1
    }
    NPM_DIR="$(dirname "${NPM_BIN}")"
    (cd "${MCP_DST}" && PATH="${NPM_DIR}:${PATH}" "${NPM_BIN}" prune --omit=dev --ignore-scripts --no-audit --no-fund)
    rm -rf "${MCP_DST}/node_modules/.vite" "${MCP_DST}/node_modules/.vite-temp"
    find "${MCP_DST}/node_modules" -type d -empty -delete
else
    rm -rf "${MCP_DST}/node_modules"
    echo "warning: mcp/node_modules not found — run ./scripts/build-mcp.sh to embed MCP runtime dependencies"
fi

if [ -x "${BRIDGE_SRC}" ]; then
    cp "${BRIDGE_SRC}" "${BRIDGE_DST}"
    chmod +x "${BRIDGE_DST}"
else
    echo "warning: equinox-bridge not built — MCP bridge will not be embedded"
fi
