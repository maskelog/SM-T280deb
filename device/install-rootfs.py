#!/usr/bin/env python3
"""Install out/rootfs.tar.gz onto the SM-T280 userdata partition from TWRP.

ERASES userdata (internal storage: Android apps, data, photos). Only userdata
is touched; SYSTEM, KERNEL, RECOVERY and the SD card are left alone.
"""
import argparse, hashlib
from pathlib import Path
from adb_common import adb, sh, by_name, require_twrp_on_sm_t280

p = argparse.ArgumentParser()
p.add_argument('rootfs', type=Path, nargs='?', default=Path(__file__).parent.parent/'out/rootfs.tar.gz')
p.add_argument('--yes-erase-userdata', action='store_true', required=True)
args = p.parse_args()
require_twrp_on_sm_t280()
data = by_name('userdata')
assert data.startswith('/dev/block/mmcblk0p'), data
want = hashlib.sha256(args.rootfs.read_bytes()).hexdigest()

for _ in range(3):   # TWRP mounts /data and binds /sdcard onto it
    for m in sorted([l.split()[1] for l in sh('cat /proc/mounts').splitlines() if l.startswith(data + ' ')],
                    key=len, reverse=True):
        sh(f'umount {m} 2>/dev/null || umount -l {m}')
assert data + ' ' not in sh('cat /proc/mounts'), 'userdata still mounted'
print(sh(f'make_ext4fs {data} 2>&1').strip().splitlines()[-1])
sh(f'mkdir -p /tmp/deb && mount -t ext4 {data} /tmp/deb')
adb('push', str(args.rootfs), '/tmp/rootfs.tar.gz', timeout=1800)
assert sh('sha256sum /tmp/rootfs.tar.gz').split()[0] == want, 'pushed archive mismatch'
out = sh('cd /tmp/deb && tar -xzpf /tmp/rootfs.tar.gz 2>&1; echo rc=$?', timeout=1800)
sh('rm -f /tmp/rootfs.tar.gz; sync')
check = sh('cat /tmp/deb/etc/sm-t280deb-build; ls -ln /tmp/deb/sbin/init /tmp/deb/usr/bin/sudo; df -h /tmp/deb | tail -1')
sh('umount /tmp/deb')
print(check)
assert 'rc=0' in out, out
print('Debian installed on', data)
