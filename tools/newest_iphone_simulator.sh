#!/bin/bash
# Sourced by the scripts whose result depends on the screen and the iOS
# version (the accessibility audit, the launch time, the smoke test): the same
# simulator on a Mac and in CI — the newest iOS runtime, on an iPhone Duo.
#
#   source tools/newest_iphone_simulator.sh "Foulee Audit"
#
# The iPhone Duo is named rather than taken as « the last iPhone the runtime
# lists »: that order is the runtime's, not a promise, and on iOS 27.2 it gave
# an iPhone 11 — the audit then ran on a small screen and reported every
# clipped label as new. The baselines are recorded on an iPhone Duo. A second
# argument asks for another device type.
#
# Sets SIMULATOR_UDID, created under that name if missing and booted, and
# SIMULATOR_NAME, « <iPhone>, iOS <version> », which the scripts record beside
# their baseline.

DEVICE_TYPE_ID="${2:-com.apple.CoreSimulator.SimDeviceType.iPhone-Duo}"
# The newest runtime that supports it. Several runtimes can share a version
# (iOS 27.2 ships a general one and one for the iPhone Duo alone), so the
# runtime is chosen by the device, not the device by the runtime. Versions
# compare as numbers: as strings, 27.10 would sort before 27.2.
RUNTIME=$(xcrun simctl list runtimes available -j \
  | jq -c --arg type "$DEVICE_TYPE_ID" '[.runtimes[]
      | select(.platform == "iOS")
      | select(any(.supportedDeviceTypes[]; .identifier == $type))]
    | sort_by(.version | split(".") | map(tonumber)) | last')
if [ "$RUNTIME" = "null" ]; then
  echo "error: no iOS runtime has a $DEVICE_TYPE_ID simulator" >&2
  exit 1
fi
RUNTIME_ID=$(echo "$RUNTIME" | jq -r .identifier)
DEVICE_TYPE=$(echo "$RUNTIME" | jq -c --arg type "$DEVICE_TYPE_ID" \
  '.supportedDeviceTypes[] | select(.identifier == $type)')
SIMULATOR_NAME="$(echo "$DEVICE_TYPE" | jq -r .name), iOS $(echo "$RUNTIME" | jq -r .version)"
SIMULATOR_UDID=$(xcrun simctl list devices available -j \
  | jq -r --arg runtime "$RUNTIME_ID" --arg type "$DEVICE_TYPE_ID" --arg name "$1" \
    '.devices[$runtime] // [] | map(select(.name == $name and .deviceTypeIdentifier == $type)) | first | .udid // empty')
[ -n "$SIMULATOR_UDID" ] || SIMULATOR_UDID=$(xcrun simctl create "$1" "$DEVICE_TYPE_ID" "$RUNTIME_ID")
echo "==> $1 on $SIMULATOR_NAME ($SIMULATOR_UDID)"
# Booted before the run, for the same reason as CI's iOS job (issue #404).
xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null
