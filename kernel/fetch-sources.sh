#!/usr/bin/env bash
# Download the pinned vendor kernel and toolchain archives and verify them.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p downloads
fetch() {   # name github-repo commit sha256
    local out="downloads/$1.tar.gz"
    [ -f "$out" ] || curl -fL --retry 3 -o "$out" "https://codeload.github.com/$2/tar.gz/$3"
    if ! echo "$4  $out" | sha256sum -c --quiet; then
        echo "WARNING: $out hash differs from the pinned value ($4)." >&2
        echo "GitHub may have regenerated the archive; check the commit $3 yourself." >&2
        exit 1
    fi
}
fetch kernel    underscoremone/android_kernel_samsung_gtexswifi \
    119009375ba2633dcd501cc8ab81b05a4645e50a 094aa833f6a4a09b06a519cc4cbd60f64ac698ec9a48a29faafdce865e84fb08
fetch toolchain underscoremone/android_prebuilts_gcc_linux-x86_arm_arm-eabi \
    6dc2f9c8c23dc780fe867751917c6967d735ed2a 8487aaf9d2f506d45fabc8966dbf1e6f96267e4aef92f17084024519e14d6b22
# device tree: only for the sprd_sign tool used by boot/sign.sh
fetch device    underscoremone/android_device_samsung_gtexswifi     0826fd4d9714e0c5568383a408a55801b958c9c2 fd5d983a6a938f4793e408bf3244045e2b0395ed1bd24d1d5c648b40560c49db
# ARM Mali Utgard r6p2 kernel driver (GPL), replaces the vendor r6p0 driver
out=downloads/mali-utgard-r6p2.tgz
[ -f "$out" ] || curl -fL --retry 3 -o "$out" \
    https://developer.arm.com/-/media/Files/downloads/mali-drivers/kernel/mali-utgard-gpu/DX910-SW-99002-r6p2-01rel0.tgz
echo "bb49d23ab3d9fbeb701a127e6f28cff1c963bba05786f98d76edff1df0fe6c52  $out" | sha256sum -c --quiet
echo "sources ready in downloads/"
