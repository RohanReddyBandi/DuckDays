#!/bin/sh
# Exercises the pure logic in Shared/ against the real sources, compiled for
# the Mac: countdown phrasing, tolerant decoding of older payloads, and the
# share-link round trip.
#
# There is no test target in the project, and this is the logic with enough
# branches to be worth pinning — two precisions, both directions, payloads
# written by a version that had neither ids nor precision, and links that have
# to survive base64url, emoji, and a duck this build has never heard of.
#
#     sh tools/test-shared.sh
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -O "$root/Shared/Countdown.swift" \
    "$root/Shared/CountdownShare.swift" \
    "$root/tools/PhrasingTests/stub.swift" \
    "$root/tools/PhrasingTests/main.swift" \
    -o "$out/run"
"$out/run"
