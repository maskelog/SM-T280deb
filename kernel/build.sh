#!/usr/bin/env bash
# Build the SM-T280 Debian kernel (3.10.108 vendor tree + kernel/patches) and
# the out-of-tree SC2331 Wi-Fi module. Output: out/kernel/{Image,sprdwl.ko,...}
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-/var/tmp/sm-t280deb-kernel}
RELEASE=${RELEASE:--sm-t280deb}
OUT="$REPO/out/kernel"
mkdir -p "$OUT"
[ -f "$REPO/downloads/kernel.tar.gz" ] || "$REPO/kernel/fetch-sources.sh"
if [ ! -x "$WORK/toolchain/bin/arm-eabi-gcc" ]; then
    rm -rf "$WORK"; mkdir -p "$WORK/kernel" "$WORK/toolchain" "$WORK/out"
    tar -xzf "$REPO/downloads/toolchain.tar.gz" --strip-components=1 -C "$WORK/toolchain"
    tar -xzf "$REPO/downloads/kernel.tar.gz" --strip-components=1 -C "$WORK/kernel"
    for p in 0001 0002 0003 0004 0005 0006 0008; do
        patch -d "$WORK/kernel" -p1 --batch --fuzz=0 < "$REPO"/kernel/patches/$p-*.patch > /dev/null
    done
    sed -n '/^diff --git/,$p' "$REPO/kernel/ambient-caps/58319057b784-capabilities-ambient.patch" \
        | patch -d "$WORK/kernel" -p1 --batch --no-backup-if-mismatch > /dev/null
    python3 "$REPO/kernel/ambient-caps/adapt-prctl-3.10.py" "$WORK/kernel"
    for p in 0009 0010; do
        patch -d "$WORK/kernel" -p1 --batch --fuzz=0 < "$REPO"/kernel/patches/$p-*.patch > /dev/null
    done
fi
export ARCH=arm CROSS_COMPILE="$WORK/toolchain/bin/arm-eabi-"
MAKE=(make -C "$WORK/kernel" O="$WORK/out" HOSTCFLAGS='-O2 -fcommon' LOCALVERSION="$RELEASE")
"${MAKE[@]}" gtexswifi-dt_defconfig > "$OUT/config.log" 2>&1
"$WORK/kernel/scripts/kconfig/merge_config.sh" -m -O "$WORK/out" "$WORK/out/.config" "$REPO/kernel/debian.fragment" >> "$OUT/config.log" 2>&1
"${MAKE[@]}" olddefconfig >> "$OUT/config.log" 2>&1
"${MAKE[@]}" -j"$(nproc)" Image > "$OUT/build.log" 2>&1
"${MAKE[@]}" M="$WORK/kernel/drivers/net/wireless/sc2331" -j"$(nproc)" modules > "$OUT/wifi.log" 2>&1
cp "$WORK/out/arch/arm/boot/Image" "$WORK/out/System.map" "$OUT/"
cp "$WORK/out/.config" "$OUT/kernel.config"
cp "$WORK/kernel/drivers/net/wireless/sc2331/sprdwl.ko" "$OUT/"
"${CROSS_COMPILE}strip" --strip-debug "$OUT/sprdwl.ko"
# fbpan: tiny freestanding helper for the command-mode panel (see tools/fbpan.c)
"${CROSS_COMPILE}gcc" -Os -march=armv7-a -marm -ffreestanding -fno-builtin -fno-stack-protector \
    -nostdlib -static -Wl,-e,_start,-Ttext-segment=0x10000 -Wall -Wextra -Werror \
    "$REPO/tools/fbpan.c" -lgcc -o "$OUT/fbpan"
"${CROSS_COMPILE}strip" "$OUT/fbpan"
(cd "$OUT" && sha256sum Image sprdwl.ko fbpan kernel.config > SHA256SUMS)
echo "kernel: $(strings "$OUT/Image" | grep -m1 'Linux version' | cut -d' ' -f1-3)"
