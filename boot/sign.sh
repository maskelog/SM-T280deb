#!/usr/bin/env bash
# Sign a boot image with sprd_sign from the original gtexswifi device tree
# (downloads/device.tar.gz, fetched by kernel/fetch-sources.sh). Signs in place
# (appends 660 bytes) and checks the result.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
IMG=$(realpath "$1")
DEV="$REPO/downloads/device"
if [ ! -x "$DEV/signimage/prebuilt/bin/sprd_sign" ]; then
    mkdir -p "$DEV"; tar -xzf "$REPO/downloads/device.tar.gz" --strip-components=1 -C "$DEV"
fi
before=$(stat -c %s "$IMG")
"$DEV/signimage/prebuilt/bin/sprd_sign" "$IMG" "$DEV/signimage/config" > /dev/null
after=$(stat -c %s "$IMG")
[ $((after - before)) -eq 660 ] || { echo "signing failed ($before -> $after bytes)"; exit 1; }
echo "signed: $IMG ($after bytes) sha256 $(sha256sum "$IMG" | cut -d' ' -f1)"
