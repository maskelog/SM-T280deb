#!/usr/bin/env python3
"""Pack a kernel + initramfs into the SM-T280 (Samsung/Spreadtrum) boot format.

Layout: 512-byte DHTB header (payload SHA256 + length), Android v0 boot image
with a separate DT, and Samsung's SEANDROIDENFORCE trailer. All headers, the
DT image and the trailer are copied from your OWN stock boot image (--template);
only kernel, ramdisk and sizes change. Sign the result with boot/sign.sh.
Note: the S-Boot bootloader ignores the cmdline stored in the image.
"""
import argparse, hashlib, struct
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--template', type=Path, required=True, help='your stock boot partition dump')
p.add_argument('--kernel', type=Path, required=True)
p.add_argument('--ramdisk', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()

orig = args.template.read_bytes()
assert orig[:4] == b'DHTB' and orig[512:520] == b'ANDROID!', 'template is not a DHTB boot image'
payload = orig[512:512 + struct.unpack_from('<I', orig, 48)[0]]
ks, _, rs, _, ss, _, _, page, ds, _ = struct.unpack_from('<10I', payload, 8)
assert page == 2048 and ss == 0
align = lambda n, a: (n + a - 1) // a * a
dt_off = page + align(ks, page) + align(rs, page)
dt = payload[dt_off:dt_off + ds]
tail = payload[dt_off + align(ds, page):]
assert tail.startswith(b'SEANDROIDENFORCE'), 'unexpected trailer in template'

kernel, ramdisk = args.kernel.read_bytes(), args.ramdisk.read_bytes()
assert ramdisk[:2] == b'\x1f\x8b', 'ramdisk must be gzip-compressed cpio'
hdr = bytearray(payload[:page])
struct.pack_into('<I', hdr, 8, len(kernel))
struct.pack_into('<I', hdr, 16, len(ramdisk))
struct.pack_into('<I', hdr, 40, len(dt))
h = hashlib.sha1()
for d in (kernel, ramdisk, b''):
    h.update(d); h.update(struct.pack('<I', len(d)))
h.update(dt); h.update(struct.pack('<I', len(dt)))
hdr[576:608] = h.digest() + bytes(12)
body = bytes(hdr) + b''.join(d + bytes(align(len(d), page) - len(d)) for d in (kernel, ramdisk, dt)) + tail
body += bytes(align(len(body), 16) - len(body))
dhtb = bytearray(orig[:512])
dhtb[8:40] = hashlib.sha256(body).digest()
struct.pack_into('<I', dhtb, 48, len(body))
img = bytes(dhtb) + body
assert len(img) + 660 < 16 * 1024 * 1024, 'signed image would not fit the 16 MiB KERNEL partition'
args.output.write_bytes(img)
print(f'{args.output}: {len(img)} bytes (unsigned); sign it with boot/sign.sh')
