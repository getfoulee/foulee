#!/bin/bash
# The iPhone app's cold launch time against its budget (issues #613, #795).
#
#   tools/launch_time.sh            # fails when the launch is clearly slower
#   tools/launch_time.sh --record   # rewrites the budget from this run
#
# Runs the FouleeLaunchTime scheme: seven rounds, each opening Settings and
# then Foulée in capture mode, timed until their first screen is up. The
# fastest Foulée launch is divided by the fastest Settings launch, and that
# ratio is compared with FouleeLaunchTime/LaunchTimeBudget.json: more than
# `tolerancePercent` above the recorded one fails.
#
# A ratio rather than a time (#795): CI runners differ, and one commit measured
# 12.6 s then 10.3 s. A slow runner slows Settings as much as Foulée; a real
# regression — a heavy query or a synchronous load moved onto the launch path —
# slows Foulée alone. The fastest of seven rather than the median: a busy
# runner only ever adds time, to one launch more than another.
#
# Capture mode exists only in Debug, so this is a Debug launch: slower than
# what a user sees, and only meaningful compared with itself.
#
# Each run writes what the budget would be after it to
# build/launch/LaunchTimeBudget.json; CI keeps it as an artifact. Record on
# CI's simulator — take the artifact — rather than on a Mac, and read the diff
# before committing, since a higher ratio is a slowdown accepted.

set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
RECORD=0
[ "${1:-}" = "--record" ] && RECORD=1
OUT=build/launch
BUDGET=FouleeLaunchTime/LaunchTimeBudget.json
# Where CI's report-test-failure action looks for result bundles.
RESULT_BUNDLE=build/results/launch.xcresult
# Its own build folder, outside the checkout, as tools/accessibility_audit.sh
# does.
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/FouleeLaunch"
rm -rf "$OUT" "$RESULT_BUNDLE" && mkdir -p "$OUT" build/results

source tools/newest_iphone_simulator.sh "Foulee Launch"

# No diagnostics collection (issue #420): the iOS 27 simulator never answers.
xcodebuild test \
  -workspace Foulee.xcworkspace \
  -scheme FouleeLaunchTime \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -collect-test-diagnostics never \
  | tee "$OUT/xcodebuild.log" \
  | (xcbeautify 2>/dev/null || cat)

python3 - "$OUT/xcodebuild.log" "$OUT/LaunchTimeBudget.json" "$SIMULATOR_NAME" "$BUDGET" "$RECORD" \
  "${GITHUB_STEP_SUMMARY:-/dev/null}" <<'PY'
import json, re, sys

log, destination, device, budget_path, record, summary = sys.argv[1:7]
rounds = [
    (float(m.group(1)), float(m.group(2)))
    for m in re.finditer(r"LAUNCH_ROUND \d+ reference=([\d.]+) foulee=([\d.]+)", open(log).read())
]
if not rounds:
    sys.exit("No LAUNCH_ROUND line in the test output: the launch test did not run to its end.")
reference = min(r for r, _ in rounds)
foulee = min(f for _, f in rounds)
ratio = round(foulee / reference, 3)

with open(budget_path) as handle:
    budget = json.load(handle)
with open(destination, "w") as handle:
    json.dump(budget | {"ratio": ratio, "recordedOn": device}, handle, indent=2, sort_keys=True)
    handle.write("\n")

limit = budget["ratio"] * (1 + budget["tolerancePercent"] / 100)
passed = record == "1" or ratio <= limit
lines = [
    f"Launch over {len(rounds)} rounds: Foulée {foulee:.3f} s, Settings {reference:.3f} s (fastest of each)",
    f"Ratio {ratio:.3f}, budget {budget['ratio']:.3f} + {budget['tolerancePercent']} % = {limit:.3f}",
]
print("\n".join(lines))
with open(summary, "a") as handle:
    handle.write("### Launch time\n\n| | Fastest |\n|---|---|\n")
    handle.write(f"| Foulée | {foulee:.3f} s |\n| Settings (reference) | {reference:.3f} s |\n")
    handle.write(f"| Ratio | {ratio:.3f} |\n| Budget | {limit:.3f} ({budget['ratio']:.3f} + {budget['tolerancePercent']} %) |\n\n")
    handle.write(("✅ Within budget" if passed else "❌ Over budget") + f" on {device}.\n")
if budget["recordedOn"] != device:
    print(f"warning: the budget was recorded on {budget['recordedOn']}, this run is on {device}")
if not passed:
    sys.exit(f"error: Foulée launches in {ratio:.3f}× Settings' time, over its budget of {limit:.3f}×")
PY

if [ "$RECORD" = 1 ]; then
  cp "$OUT/LaunchTimeBudget.json" "$BUDGET"
  echo "==> Budget rewritten: $BUDGET"
fi
