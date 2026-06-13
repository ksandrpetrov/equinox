#!/bin/sh
# Exit unless the host is Apple Silicon (arm64).

if [ "$(uname -m)" != "arm64" ]; then
    echo "equinox requires Apple Silicon (arm64). Intel Macs are not supported." >&2
    exit 1
fi
