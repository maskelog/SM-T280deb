#!/usr/bin/env bash
# Build the SM-T280 initramfs: busybox from the built rootfs and an /init that
# finds the "userdata" partition by name and switch_roots into Debian. If that
# fails it offers a rescue shell on the USB ACM serial port.
# Run as root. Output: out/initramfs.cpio.gz
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
ROOTFS=${ROOTFS:-/var/tmp/sm-t280deb-rootfs/rootfs}
INIT=$(mktemp -d)
trap 'rm -rf "$INIT"' EXIT
mkdir -p "$INIT"/{bin,dev,proc,sys,newroot}
cp "$ROOTFS/usr/bin/busybox" "$INIT/bin/busybox"   # busybox-static
cat > "$INIT/init" <<'EOF'
#!/bin/busybox sh
/bin/busybox --install -s /bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
log() { echo "sm-t280-initramfs: $*" > /dev/kmsg; }
DEV=""
for i in $(seq 1 100); do
    for u in /sys/class/block/*/uevent; do
        grep -q '^PARTNAME=userdata$' "$u" 2>/dev/null && DEV=/dev/$(grep '^DEVNAME=' "$u" | cut -d= -f2)
    done
    [ -n "$DEV" ] && [ -b "$DEV" ] && break
    sleep 0.1
done
log "root device: ${DEV:-not found}"
if [ -n "$DEV" ] && mount -t ext4 -o rw,noatime "$DEV" /newroot && [ -x /newroot/sbin/init ]; then
    mount --move /dev /newroot/dev
    umount /proc /sys
    exec switch_root /newroot /sbin/init
fi
log "rescue: Debian root not mountable; shell on USB ACM"
G=/sys/class/android_usb/android0
echo 0 > $G/enable; echo 18D1 > $G/idVendor; echo 4EE5 > $G/idProduct
echo acm > $G/functions; echo 1 > $G/enable
while true; do setsid sh -c 'exec sh </dev/ttyGS0 >/dev/ttyGS0 2>&1'; sleep 1; done
EOF
chmod 755 "$INIT/init"
mkdir -p "$REPO/out"
(cd "$INIT" && find . | cpio -o -H newc --quiet | gzip -9n) > "$REPO/out/initramfs.cpio.gz"
echo "initramfs: $(du -h "$REPO/out/initramfs.cpio.gz" | cut -f1)"
