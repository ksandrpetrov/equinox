#!/bin/bash
# Native XCTest, including an isolated graphics host. Never launches equinox.app.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/require-arm64.sh

mode=
iterations=1
result_dir=
configuration=All
suite=all
thread_sanitizer=NO
filter=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) mode="${2:?Missing mode}"; shift 2 ;;
        --iterations) iterations="${2:?Missing iteration count}"; shift 2 ;;
        --result-dir) result_dir="${2:?Missing result directory}"; shift 2 ;;
        --configuration) configuration="${2:?Missing configuration}"; shift 2 ;;
        --suite) suite="${2:?Missing suite}"; shift 2 ;;
        --thread-sanitizer) thread_sanitizer=YES; shift ;;
        --filter) filter=("-only-testing:${2:?Missing XCTest identifier}"); shift 2 ;;
        --help)
            echo 'Usage: scripts/test.sh [--mode all|regression|stability|mutation] [--iterations N] [--configuration Debug|Release|All] [--suite unit|graphics|all] [--filter target/Class[/method]] [--thread-sanitizer]'
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

if [[ -z "$mode" ]]; then
    mode=all
    if [[ "$suite" != all || ${#filter[@]} -gt 0 || "$thread_sanitizer" == YES ]]; then mode=regression; fi
fi
case "$mode" in
    all|regression|stability|mutation) ;;
    *) echo "Invalid mode: $mode" >&2; exit 2 ;;
esac
if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
    echo '--iterations must be a positive integer' >&2; exit 2
fi
if [[ "$mode" != regression && ( ${#filter[@]} -gt 0 || "$suite" != all || -n "$result_dir" || "$iterations" != 1 || "$thread_sanitizer" == YES ) ]]; then
    echo 'Use --mode regression for --suite, --filter, --iterations, --result-dir or --thread-sanitizer' >&2; exit 2
fi
python3 scripts/test-audit-tests.py
if [[ "$mode" == all || "$mode" == stability ]]; then
    # Five full runs followed by twenty further runs stress order/lifetime isolation.
    # Every iteration must pass; this is repetition, never retry-until-success.
    EQUINOX_TEST_ORDER=random EQUINOX_TEST_LANGUAGE=en EQUINOX_TEST_TIMEZONE=UTC \
        "$0" --mode regression --configuration "$configuration" --iterations 5
    EQUINOX_TEST_ORDER=random EQUINOX_TEST_LANGUAGE=ru EQUINOX_TEST_TIMEZONE=America/Los_Angeles \
        "$0" --mode regression --configuration "$configuration" --iterations 20
fi
if [[ "$mode" == all ]]; then
    "$0" --mode regression --configuration "$configuration" --suite unit --thread-sanitizer
fi
if [[ "$mode" == all || "$mode" == mutation ]]; then
    python3 scripts/test-audit.py --configuration "$configuration"
fi
if [[ "$mode" != regression ]]; then
    exit 0
fi

default_derived=build/Tests
if [[ "$thread_sanitizer" == YES ]]; then default_derived=build/TestsThreadSanitizer; fi
derived="${EQUINOX_TEST_DERIVED_DATA:-$default_derived}"
packages="${EQUINOX_PACKAGE_CACHE:-build/DerivedData/SourcePackages}"
mkdir -p "$derived/results"
if [[ -z "$result_dir" ]]; then
    result_dir=$(mktemp -d "$derived/results/run-XXXXXX")
else
    mkdir -p "$result_dir"
fi
repetition=()
if [[ "$iterations" != 1 ]]; then
    repetition=(-test-iterations "$iterations" -test-repetition-relaunch-enabled YES)
fi
for configuration in "${configurations[@]}"; do
    for scheme in "${schemes[@]}"; do
        result="$result_dir/$scheme-$configuration"
        echo "Testing $scheme ($configuration): $result.log"
        if ! xcodebuild -project equinox.xcodeproj -scheme "$scheme" \
            -configuration "$configuration" -destination 'platform=macOS,arch=arm64' \
            -derivedDataPath "$derived" -clonedSourcePackagesDirPath "$packages" \
            -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
            -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES \
            -enableThreadSanitizer "$thread_sanitizer" \
            build-for-testing > "$result-build.log" 2>&1; then
            tail -100 "$result-build.log" >&2
            echo '** TEST BUILD FAILED **' >&2
            exit 1
        fi
        # Edit only Xcode's generated run settings, never the shared project/schemes.
        # Keeping the copy beside the original preserves __TESTROOT__ expansion.
        run_settings=$(python3 - "$derived/Build/Products" "$scheme" "$configuration" <<'SETTINGS'
import os, pathlib, plistlib, sys
root, scheme, configuration = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
candidates = []
for path in root.glob('*.xctestrun'):
    if path.name.startswith('audit-'):
        continue
    data = plistlib.loads(path.read_bytes())
    targets = [t for c in data.get('TestConfigurations', []) for t in c.get('TestTargets', [])]
    if not targets:
        targets = [v for v in data.values() if isinstance(v, dict) and 'TestBundlePath' in v]
    matched = [t for t in targets if t.get('BlueprintName') == scheme and ('/' + configuration + '/') in (t.get('TestBundlePath', '') + t.get('TestHostPath', ''))]
    if matched:
        candidates.append((path, data, matched))
if len(candidates) != 1:
    raise SystemExit(f'Expected one generated xctestrun for {scheme}/{configuration}, got {len(candidates)}')
path, data, targets = candidates[0]
for target in targets:
    target['TestExecutionOrdering'] = os.environ.get('EQUINOX_TEST_ORDER', 'alphabetical')
    if os.environ.get('EQUINOX_TEST_LANGUAGE'):
        target['TestLanguage'] = os.environ['EQUINOX_TEST_LANGUAGE']
    if os.environ.get('EQUINOX_TEST_TIMEZONE'):
        target.setdefault('EnvironmentVariables', {})['TZ'] = os.environ['EQUINOX_TEST_TIMEZONE']
output = root / ('audit-' + path.name)
output.write_bytes(plistlib.dumps(data))
print(output)
SETTINGS
)
        build_failed=0
        if ! xcodebuild -xctestrun "$run_settings" -destination 'platform=macOS,arch=arm64' \
            -resultBundlePath "$result.xcresult" \
            -test-timeouts-enabled YES -maximum-test-execution-time-allowance 60 \
            -enableThreadSanitizer "$thread_sanitizer" \
            ${filter[@]+"${filter[@]}"} ${repetition[@]+"${repetition[@]}"} \
            test-without-building > "$result.log" 2>&1; then
            tail -100 "$result.log" >&2
            build_failed=1
        fi
        if ! xcrun xcresulttool get test-results summary --path "$result.xcresult" > "$result-summary.json"; then
            rm -f "$result-summary.json"
            exit 1
        fi
        python3 - "$result-summary.json" "$result.log" "$build_failed" "$iterations" <<'PY'
import json, runpy, sys
summary = json.load(open(sys.argv[1]))
print(f"{summary['passedTests']} passed, {summary['failedTests']} failed, {summary['skippedTests']} skipped")
if sys.argv[3] != '0':
    sys.exit('xcodebuild failed; inspect the xcresult and log')
if (summary['totalTestCount'] == 0 or summary['failedTests'] or summary['skippedTests']
        or summary['passedTests'] != summary['totalTestCount']):
    sys.exit('Expected a complete nonempty run with no failed or skipped tests')
if summary.get('expectedFailures'):
    sys.exit('Expected failures must not hide regressions')
iterations = int(sys.argv[4])
runs = sum(item.get('passedTests', 0) for item in summary.get('devicesAndConfigurations', []))
if iterations > 1:
    if runs != summary['passedTests'] * iterations:
        sys.exit(f'Incomplete repetitions: {runs} passes, expected {summary["passedTests"] * iterations}')
    print(f'{iterations} iterations, {runs} successful test executions')
if summary.get('runtimeWarnings'):
    sys.exit(f"Runtime warnings: {summary['runtimeWarnings']}")
# Runtime diagnostics and test-host restarts can appear only in the console,
# with an empty xcresult runtimeWarnings array. Do not report these runs as clean.
diagnostics = runpy.run_path('scripts/test-audit.py')['runtime_diagnostics'](open(sys.argv[2]).read())
if diagnostics:
    sys.exit('Runtime diagnostics:\n' + '\n'.join(diagnostics))
PY
        xcrun xccov view --report --json "$result.xcresult" > "$result-coverage.json"
    done
done
echo "Results: $result_dir"
