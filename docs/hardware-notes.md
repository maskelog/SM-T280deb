# SM-T280 hardware notes (as observed)

- **SoC / CPU:** Spreadtrum SC7730 (sc8830 family), 4x Cortex-A7, 32-bit only. 1.5 GB RAM (about 1.4 GB usable).
- **Bootloader:** Samsung S-Boot 4.0. Loads `KERNEL` (boot) or `RECOVERY`; no SD-card boot.
  Images use a 512-byte DHTB header + Android v0 image + separate DT + `SEANDROIDENFORCE`
  trailer and must be signed with `sprd_sign`. **The cmdline stored in the image is ignored**;
  only the bootloader's own arguments reach the kernel (`init=/init`, `console=null`, ...).
- **Display:** `sprdfb`, 800x1280, 32 bpp, `yres_virtual` 3840 (triple buffer). The MIPI panel
  is updated **only on `FBIOPAN_DISPLAY`**; writing to `/dev/fb0` alone does nothing visible.
  The panel scans out upside down relative to the tablet (home button at the bottom).
- **Touch:** `sec_touchscreen`, multitouch, axes 0-800 / 0-1280 matching the physical
  orientation. No `EV_KEY`/`BTN_TOUCH`; libinput still handles it as a touchscreen.
- **Wi-Fi/BT:** SC2331 "Marlin" on SDIO. The chip is powered and its firmware loaded by the
  stock `/system/bin/download` daemon (via `/dev/power_ctl`, `/dev/ttyS0`, `/dev/download`);
  calibration lives in the `prodnv` partition. Driver: out-of-tree `sprdwl.ko`. `iw scan`
  returns EAGAIN; scanning works through wpa_supplicant (nl80211).
- **USB:** legacy `android_usb` gadget (`/sys/class/android_usb/android0`), functions include
  rndis, acm, adb (FunctionFS), mtp.
  On every re-enumeration the gadget re-creates `rndis0` (addresses lost) and the PC-side
  RNDIS MAC changes, so the IP is re-applied from udev and DHCP hands out a small pool.
- **Load average ~3 at idle** is three vendor kernel threads (`sprd_hotplug`, `wlan_trans`,
  `wlan_core`) sleeping in D state, not CPU use.
- When X blanks the panel (DPMS), `FBIOPAN_DISPLAY` fails until it is unblanked.
- **Partitions (by name):** KERNEL 16 MiB, RECOVERY 16 MiB, SYSTEM 2 GiB, userdata ~12.3 GiB
  (16 GB model), efs, prodnv. Use names, not numbers.
- **Kernel config gaps vs. modern userspace:** no cgroup v2, no eBPF, no ambient caps or
  FunctionFS AIO (patched), no `/proc/sys/vm/mmap_rnd_bits` (patched). Debian uses sysvinit.
