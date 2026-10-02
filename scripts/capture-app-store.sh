#!/bin/bash
# Render shipping SwiftUI screens with isolated fixtures using the existing XCTest host.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/require-arm64.sh

mkdir -p build/AppStoreListing
capture_dir=$(mktemp -d build/AppStoreListing/run-XXXXXX)
for language in ru en; do
    region=US
    [[ "$language" == ru ]] && region=RU
    result="$capture_dir/$language.xcresult"
    echo "Capturing App Store screenshots ($language): $result"
    if ! xcodebuild -project equinox.xcodeproj -scheme equinoxGraphicsTests \
        -configuration Release -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath build/Tests -clonedSourcePackagesDirPath build/DerivedData/SourcePackages \
        -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
        -testLanguage "$language" -testRegion "$region" -resultBundlePath "$result" \
        -only-testing:equinoxGraphicsTests/SurfaceLayoutTests/testStoreListingScreenshots \
        CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES test > "$capture_dir/$language.log" 2>&1; then
        tail -80 "$capture_dir/$language.log" >&2
        exit 1
    fi
    xcrun xcresulttool get test-results summary --path "$result" > "$capture_dir/$language-summary.json"
    xcrun xcresulttool export attachments --path "$result" --output-path "$capture_dir/$language-attachments" > /dev/null
done

python3 - "$capture_dir" <<'PY'
import json
import shutil
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
for language in ('ru', 'en'):
    summary = json.loads((root / f'{language}-summary.json').read_text())
    if summary['passedTests'] != 1 or summary['failedTests'] or summary['skippedTests']:
        raise SystemExit(f'Unexpected screenshot test result: {language}')
    folder = root / f'{language}-attachments'
    manifest = json.loads((folder / 'manifest.json').read_text())
    attachments = [item for test in manifest for item in test['attachments']]
    target = Path('docs/app-store/screenshots') / language
    target.mkdir(parents=True, exist_ok=True)
    for name in ('01-calendar', '02-event', '03-appearance'):
        prefix = f'store-{language}-{name}'
        matches = [a for a in attachments if a['suggestedHumanReadableName'].startswith(prefix)]
        if len(matches) != 1:
            raise SystemExit(f'Expected one attachment for {prefix}, got {len(matches)}')
        source = folder / matches[0]['exportedFileName']
        data = source.read_bytes()
        width, height, depth, color = struct.unpack('>IIBB', data[16:26])
        if data[:8] != b'\x89PNG\r\n\x1a\n' or (width, height, depth, color) != (2880, 1800, 8, 2):
            raise SystemExit(f'Expected RGB PNG 2880x1800: {source}')
        shutil.copyfile(source, target / f'{name}.png')
    print(f'{language}: 3 RGB screenshots, 2880x1800')
print(f'Capture evidence: {root}')
PY
