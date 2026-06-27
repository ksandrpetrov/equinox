#!/bin/bash
#
# Load signing settings from Local.xcconfig as xcodebuild command-line
# overrides. Target-level Xcode settings otherwise take precedence over the
# base xcconfig and can force a stale local signing identity.

XCODEBUILD_LOCAL_SETTINGS=()

load_xcodebuild_local_settings() {
    local config_path="${1:-Local.xcconfig}"
    XCODEBUILD_LOCAL_SETTINGS=()

    if [ ! -f "${config_path}" ]; then
        return 0
    fi

    local assignment
    while IFS= read -r assignment; do
        if [ -n "${assignment}" ]; then
            XCODEBUILD_LOCAL_SETTINGS+=("${assignment}")
        fi
    done < <(
        awk '
            /^[[:space:]]*(\/\/|$)/ { next }
            {
                line = $0
                sub(/[[:space:]]*\/\/.*$/, "", line)
                equals = index(line, "=")
                if (equals == 0) { next }

                key = substr(line, 1, equals - 1)
                value = substr(line, equals + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

                if (key ~ /^(DEVELOPMENT_TEAM|CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|ENABLE_HARDENED_RUNTIME)$/) {
                    print key "=" value
                }
            }
        ' "${config_path}"
    )
}
