# SM-T280deb — Debian 13 for the Samsung Galaxy Tab A 7.0 (2016) Wi-Fi (SM-T280)

Debian 13 "trixie" (armhf) running on the SM-T280 with the vendor 3.10 kernel:
XFCE desktop on the built-in screen, touch, Wi-Fi, SSH. Unofficial; not
affiliated with Samsung or Debian. **Use at your own risk.**

[한국어 설명](README.ko.md) · [hardware notes](docs/hardware-notes.md) · [kernel patches](kernel/README.md)

## Status

| Feature | State |
|---|---|
| Boot (signed boot image + initramfs, root on internal `userdata`) | works |
| Display (Xorg fbdev + XFCE, rotated 180°) | works, software rendering only |
| Touchscreen | works |
| Wi-Fi (SC2331) | works; panel applet (wpa_gui) to scan and join networks; needs the firmware loader from your own Android system |
| USB networking (RNDIS) + serial console (ACM) | works, survives cable replug / PC re-enumeration (tablet 192.168.7.2, PC gets 192.168.7.10-99) |
| On-screen keyboard (onboard) | works: docked at the bottom, shown when a text field is focused |
| Screen rotation | portrait / landscape via `sm-t280-rotate` or the XFCE menu (restarts the session) |
| Audio, camera, Bluetooth, GPU acceleration, suspend | not done |

## What you need

- An SM-T280 with **TWRP** in RECOVERY (TWRP stays installed; it is your way back).
- A Linux host (Debian/Ubuntu, WSL2 works) with: `build-essential bc python3 curl
  mmdebstrap qemu-user binfmt (qemu-user-binfmt / qemu-user-static) arch-test cpio
  e2fsprogs binutils adb`.
- Dumps from **your own tablet** (made in TWRP), kept outside this repository:
  - `boot.img` — the stock KERNEL partition (template for headers and DT),
  - `system.img` — the stock SYSTEM partition (source of the Wi-Fi firmware loader).

  ```sh
  adb exec-out "dd if=/dev/block/platform/sdio_emmc/by-name/KERNEL"  > boot.img
  adb exec-out "dd if=/dev/block/platform/sdio_emmc/by-name/SYSTEM" > system.img
  ```

## Build

```sh
kernel/build.sh                                   # out/kernel/{Image,sprdwl.ko,fbpan}
device/extract-android-blobs.sh system.img blobs  # proprietary files from YOUR system
sudo SSH_PUBKEY=~/.ssh/id_ed25519.pub USER_PASSWORD='choose-one' \
     ANDROID_SYSTEM=$PWD/blobs/system rootfs/build-rootfs.sh   # out/rootfs.tar.gz, out/initramfs.cpio.gz
boot/pack-boot.py --template boot.img --kernel out/kernel/Image \
     --ramdisk out/initramfs.cpio.gz --output out/boot.img
boot/sign.sh out/boot.img
```

## Install (in TWRP)

**This erases the internal storage (`userdata`).** Android stays on SYSTEM but
will not boot until you restore your stock boot image.

```sh
python3 device/install-rootfs.py out/rootfs.tar.gz --yes-erase-userdata
python3 device/flash-boot-twrp.py out/boot.img --backup boot-before-debian.img
adb reboot
```

First boot takes about a minute. To change orientation use Settings → "Rotate: ..." in
the XFCE menu or `sm-t280-rotate portrait|landscape-home-right|landscape-home-left`;
the panel driver only rotates at X start, so the desktop restarts (~10 s).
 Then connect over USB (`ssh debian@192.168.7.2`)
or pick a Wi-Fi network from the panel icon (wpa_gui), or add it in a terminal:
`wpa_passphrase "SSID" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant-wlan0.conf`.

## Going back to Android

Boot TWRP (hold Volume Up + Home + Power), restore your stock `boot.img` to
KERNEL (e.g. `flash-boot-twrp.py boot.img --backup ...` or TWRP's image flash),
then format Data in TWRP.

## Licensing

GPL-2.0 (see `LICENSE`); the kernel patches are derived from Linux. This
repository contains **no** Samsung/Spreadtrum binaries, firmware or signing keys:
the firmware loader is extracted from your own device, and `sprd_sign` is
downloaded from the original LineageOS gtexswifi device tree at build time.

## Credits

Vendor kernel, toolchain and device tree: underscoremone (LineageOS 14.1 for
gtexswifi). Upstream Linux authors of the backported patches (see each patch).
