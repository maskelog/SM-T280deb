# Kernel

Base: the vendor 3.10.108 tree used by LineageOS 14.1 for gtexswifi
(`underscoremone/android_kernel_samsung_gtexswifi@119009375ba`), built with the
Linaro GCC 7.5 toolchain from the same author. `fetch-sources.sh` downloads and
verifies both; `build.sh` applies the patches and `debian.fragment`.

| Patch | Purpose |
|---|---|
| 0001 | `getrandom()` syscall for ARM (backport) |
| 0002-0006 | Binder from the Android common 3.10 kernel: binder/hwbinder/vndbinder contexts, SG/FD-array transactions, transaction security context, vendor-API and user-access fixes |
| 0008 | `ARCH_MMAP_RND_BITS` / `/proc/sys/vm/mmap_rnd_bits` (upstream d07e22597d1d, e0c25d958f78) |
| ambient-caps | ambient capabilities (upstream 58319057b784); `adapt-prctl-3.10.py` rewrites the `PR_CAP_AMBIENT` case for the 3.10 creds flow (the upstream form leaks creds there) |
| 0009 | FunctionFS AIO (`aio_read`/`aio_write`), based on upstream 2e4c7553cd6f, with fixes for short-read data exposure, mm lifetime, cancel/free races and sync kiocbs |
| 0010 | sprdfb: accept `FBIOPUT_VSCREENINFO` with a smaller `yres_virtual` so Xorg fbdev can start |
| 0011 | Mali-400: the vendor r6p0 driver (API 800) is replaced by ARM's GPL r6p2-01rel0 driver (API 900, `downloads/mali-utgard-r6p2.tgz`); the patch adds the vendor sc8830 platform glue and limits external-memory binds to fb0. See [docs/gpu.md](../docs/gpu.md) |
| 0012 | sprdfb: `skip_vt_switch`, so the suspend console switch does not kill Xorg (fbdev cannot re-enter its VT) |
| 0013 | sprdfb: report the real 32 bpp channel order (R in the low byte); red and blue were swapped under Xorg |
| 0014 | hci_uart: raise the Marlin BT wake line before each transmit (what Android's libbt-vendor did), so BlueZ can use the SC2331 over UART0/H4 |

0007 (an Android-only cmdline fragment) is intentionally not included.
The Binder, mmap, ambient-capability and AIO patches came from an Android 12
bring-up of the same kernel; they are harmless for Debian and kept so one
kernel tree serves both.

`debian.fragment`: `DEVTMPFS`, `DEVTMPFS_MOUNT`, `FHANDLE` (udev) on;
`ANDROID_PARANOID_NETWORK` off (it restricts sockets to gid 3003).
