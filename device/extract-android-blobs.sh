#!/usr/bin/env bash
# Extract the Wi-Fi firmware loader and firmware, and the Bluetooth vendor
# library (only its default pskey block is read), from YOUR OWN SM-T280 Android
# system partition. These files are proprietary and are not distributed here.
#
#   extract-android-blobs.sh <system.img | mounted-system-dir> <output-dir>
#
# system.img: a raw ext4 dump of the SYSTEM partition (e.g. from TWRP:
#   adb exec-out "dd if=/dev/block/platform/sdio_emmc/by-name/SYSTEM" > system.img)
# Tested with LineageOS 14.1 (Android 7.1.2) for gtexswifi. The result is a
# minimal /system (bionic linker + the libraries the daemon needs) that
# build-rootfs.sh copies into Debian via ANDROID_SYSTEM=<output-dir>/system.
set -euo pipefail
SRC=$1; DST=$2/system
command -v readelf > /dev/null || { echo "needs readelf (binutils)"; exit 1; }
FILES="bin/linker bin/download etc/connectivity_calibration.ini etc/connectivity_configure.ini
       etc/firmware/sc2331_fdl.bin etc/firmware/sc2331_fw.bin lib/libbt-vendor.so"
get() {   # path relative to /system
    mkdir -p "$DST/$(dirname "$1")"
    if [ -d "$SRC" ]; then
        cp "$SRC/$1" "$DST/$1" 2>/dev/null || true
    else
        command -v debugfs > /dev/null || { echo "needs debugfs (e2fsprogs)"; exit 1; }
        debugfs -R "dump /$1 $DST/$1" "$SRC" 2>/dev/null || true
    fi
    [ -s "$DST/$1" ] || { rm -f "$DST/$1"; return 1; }
}
rm -rf "$DST"; mkdir -p "$DST"
for f in $FILES; do get "$f" || echo "missing: /system/$f"; done
[ -s "$DST/bin/download" ] || { echo "no /system/bin/download in $SRC"; exit 1; }
# Libraries needed by the daemon, resolved recursively
queue=$(readelf -d "$DST/bin/download" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); seen=""
while [ -n "$queue" ]; do
    set -- $queue; lib=$1; shift; queue="$*"
    case " $seen " in *" $lib "*) continue ;; esac
    seen="$seen $lib"
    get "lib/$lib" || { echo "missing library: $lib"; continue; }
    queue="$queue $(readelf -d "$DST/lib/$lib" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p')"
done
chmod 755 "$DST/bin/"*
echo "extracted to $DST:$seen"
(cd "$DST" && find . -type f | sort)
