#!/bin/bash
# Native XCTest, including an isolated graphics host. Never launches equinox.app.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/require-arm64.sh

configuration=All
suite=all
filter=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration) configuration="${2:?Missing configuration}"; shift 2 ;;
        --suite) suite="${2:?Missing suite}"; shift 2 ;;
        --filter) filter=("-only-testing:${2:?Missing XCTest identifier}"); shift 2 ;;
        --help)
            echo 'Usage: scripts/test.sh [--configuration Debug|Release|All] [--suite unit|graphics|all] [--filter target/Class[/method]]'
            echo 'Optional paths: EQUINOX_TEST_DERIVED_DATA, EQUINOX_PACKAGE_CACHE'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
case "$configuration" in
    All) configurations=(Debug Release) ;;
    Debug|Release) configurations=("$configuration") ;;
    *) echo "Invalid configuration: $configuration" >&2; exit 2 ;;
esac
case "$suite" in
    all) schemes=(equinoxTests equinoxGraphicsTests) ;;
    unit) schemes=(equinoxTests) ;;
    graphics) schemes=(equinoxGraphicsTests) ;;
    *) echo "Invalid suite: $suite" >&2; exit 2 ;;
esac
if [[ ${#filter[@]} -gt 0 && "$suite" == all ]]; then
    echo '--filter requires --suite unit or graphics' >&2
    exit 2
fi

derived="${EQUINOX_TEST_DERIVED_DATA:-build/Tests}"
packages="${EQUINOX_PACKAGE_CACHE:-build/DerivedData/SourcePackages}"
mkdir -p "$derived/results"
result_dir=$(mktemp -d "$derived/results/run-XXXXXX")
for configuration in "${configurations[@]}"; do
    for scheme in "${schemes[@]}"; do
        result="$result_dir/$scheme-$configuration"
        echo "Testing $scheme ($configuration): $result.log"
        if ! xcodebuild -project equinox.xcodeproj -scheme "$scheme" \
            -configuration "$configuration" -destination 'platform=macOS,arch=arm64' \
            -derivedDataPath "$derived" -clonedSourcePackagesDirPath "$packages" \
            -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
            -enableCodeCoverage YES -resultBundlePath "$result.xcresult" \
            CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES \
            ${filter[@]+"${filter[@]}"} test > "$result.log" 2>&1; then
            tail -100 "$result.log" >&2
            exit 1
        fi
        xcrun xcresulttool get test-results summary --path "$result.xcresult" > "$result-summary.json"
        python3 - "$result-summary.json" <<'PY'
import json, sys
summary = json.load(open(sys.argv[1]))
print(f"{summary['passedTests']} passed, {summary['failedTests']} failed, {summary['skippedTests']} skipped")
if summary['totalTestCount'] == 0 or summary['failedTests'] or summary['skippedTests']:
    sys.exit('Expected a nonempty run with no failed or skipped tests')
PY
        xcrun xccov view --report --json "$result.xcresult" > "$result-coverage.json"
    done
done
echo "Results: $result_dir"
