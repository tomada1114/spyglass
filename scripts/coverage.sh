#!/usr/bin/env bash
# Run the SpyglassKit test suite with code coverage and enforce a line-coverage
# floor on Sources/SpyglassCore. The UI layer (SpyglassUI) is deliberately exempt —
# the floor is honest because all logic lives in Core.
#
# Swift's llvm-cov has no dependable branch metric, so this gates on LINE
# coverage (uv-template gates on branch coverage; documented divergence).
#
# Override the floor with COVERAGE_MIN (e.g. COVERAGE_MIN=90 scripts/coverage.sh).
set -euo pipefail

THRESHOLD="${COVERAGE_MIN:-80}"
cd "$(dirname "$0")/../Packages/SpyglassKit"

swift test --enable-code-coverage
CODECOV_JSON="$(swift test --show-codecov-path)"

python3 - "$CODECOV_JSON" "$THRESHOLD" <<'PY'
import json, sys

data = json.load(open(sys.argv[1]))
threshold = float(sys.argv[2])
covered = total = 0
for f in data["data"][0]["files"]:
    if "/Sources/SpyglassCore/" not in f["filename"]:
        continue
    s = f["summary"]["lines"]
    covered += s["covered"]
    total += s["count"]
    pct = 100.0 * s["covered"] / s["count"] if s["count"] else 100.0
    print(f'{f["filename"]}: {pct:.1f}%')
if total == 0:
    sys.exit("coverage: no SpyglassCore files found — gate misconfigured")
pct = 100.0 * covered / total
print(f"SpyglassCore line coverage: {pct:.1f}% (floor {threshold}%)")
# Two decimals in the failure message so a near-miss never rounds up to the
# floor itself (e.g. 79.96% displayed as "80.0% is below the 80% floor").
sys.exit(0 if pct >= threshold else f"coverage {pct:.2f}% is below the {threshold}% floor")
PY
