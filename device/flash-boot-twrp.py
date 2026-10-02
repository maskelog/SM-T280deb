#!/usr/bin/env python3
"""Write a signed boot image to the SM-T280 KERNEL partition from TWRP.

Backs up the current KERNEL partition to --backup first, verifies the
readback and that RECOVERY is unchanged. Does not reboot.
"""
import argparse, hashlib, struct
from pathlib import Path
from adb_common import adb, sh, by_name, require_twrp_on_sm_t280

p = argparse.ArgumentParser()
p.add_argument('image', type=Path)
p.add_argument('--backup', type=Path, required=True, help='new file for the current boot partition')
args = p.parse_args()
img = args.image.read_bytes()
n = struct.unpack_from('<I', img, 48)[0]
assert img[:4] == b'DHTB' and img[512:520] == b'ANDROID!', 'not a DHTB boot image'
assert hashlib.sha256(img[512:512 + n]).digest() == img[8:40], 'DHTB payload hash mismatch'
assert len(img) == 512 + n + 660, 'image is not signed (run boot/sign.sh)'
require_twrp_on_sm_t280()
kernel, recovery = by_name('KERNEL'), by_name('RECOVERY')
size = int(sh(f'cat /sys/class/block/{Path(kernel).name}/size').strip()) * 512
assert len(img) < size
rec_before = sh(f'sha256sum {recovery}').split()[0]
old = adb('exec-out', f'dd if={kernel} bs=4096 2>/dev/null', timeout=300)
assert len(old) == size
with args.backup.open('xb') as f:
    f.write(old)
assert hashlib.sha256(old).hexdigest() == sh(f'sha256sum {kernel}').split()[0]
adb('push', str(args.image.resolve()), '/tmp/boot.img')
assert sh('sha256sum /tmp/boot.img').split()[0] == hashlib.sha256(img).hexdigest()
sh(f'dd if=/tmp/boot.img of={kernel} bs=4096 conv=fsync && sync')
back = adb('exec-out', f'dd if={kernel} bs=4096 2>/dev/null', timeout=300)
assert back[:len(img)] == img, 'READBACK MISMATCH - do not reboot; restore the backup'
assert sh(f'sha256sum {recovery}').split()[0] == rec_before
print(f'KERNEL written and verified; previous boot saved to {args.backup}')
