#!/bin/sh
# Exercises CountdownPhrasing and CountdownEvent decoding against the real
# Shared/Countdown.swift, compiled for the Mac.
#
# There is no test target in the project, and this is the one piece of logic
# with enough branches to be worth pinning: two precisions, three unit
# combinations, both directions past and future, and tolerant decoding of a
# payload written by a version that had neither ids nor precision.
#
#     sh tools/test-phrasing.sh
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -O "$root/Shared/Countdown.swift" \
    "$root/tools/PhrasingTests/stub.swift" \
    "$root/tools/PhrasingTests/main.swift" \
    -o "$out/run"
"$out/run"
