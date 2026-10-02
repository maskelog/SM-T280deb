#!/bin/sh
# Run ON THE TABLET as root (Debian): write a signed boot image to KERNEL.
# Backs up the current partition to /root/boot-backups, verifies the readback
# and that RECOVERY (TWRP) is unchanged. Reboot yourself afterwards.
#   flash-boot-from-debian.sh boot.img <sha256 of boot.img>
set -eu
IMG=$1; WANT=$2
part() {   # GPT partition name -> /dev node
    for u in /sys/class/block/mmcblk0p*/uevent; do
        grep -q "^PARTNAME=$1\$" "$u" && { echo "/dev/$(sed -n 's/^DEVNAME=//p' "$u")"; return; }
    done
    echo "partition $1 not found" >&2; exit 1
}
DEV=$(part KERNEL); REC=$(part RECOVERY)
[ "$(sha256sum "$IMG" | cut -d' ' -f1)" = "$WANT" ] || { echo "image hash mismatch"; exit 1; }
SIZE=$(stat -c %s "$IMG")
[ "$SIZE" -lt 16777216 ] || { echo "image too large"; exit 1; }
head -c 4 "$IMG" | grep -q DHTB || { echo "not a DHTB image"; exit 1; }
REC_BEFORE=$(sha256sum "$REC" | cut -d' ' -f1)
mkdir -p /root/boot-backups
dd if="$DEV" of=/root/boot-backups/boot-before-$(date +%Y%m%d-%H%M%S).img bs=1M status=none
dd if="$IMG" of="$DEV" bs=1M conv=fsync status=none
sync
GOT=$(head -c "$SIZE" "$DEV" | sha256sum | cut -d' ' -f1)
[ "$GOT" = "$WANT" ] || { echo "READBACK MISMATCH - do not reboot"; exit 1; }
[ "$(sha256sum "$REC" | cut -d' ' -f1)" = "$REC_BEFORE" ] || { echo "RECOVERY changed - do not reboot"; exit 1; }
echo "KERNEL ($DEV) written and verified ($SIZE bytes); RECOVERY unchanged"
