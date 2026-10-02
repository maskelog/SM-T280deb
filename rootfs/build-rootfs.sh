#!/usr/bin/env bash
# Build the SM-T280 Debian 13 (trixie, armhf) root filesystem and initramfs.
# Run as root (mmdebstrap + qemu-user binfmt for armhf).
#
# Required:
#   SSH_PUBKEY=path/to/key.pub      authorized key for user "debian"
#   USER_PASSWORD=...               password for "debian" (sudo asks for it)
#     or BRINGUP=1                  no password: serial autologin + NOPASSWD sudo
#                                   (development only - anyone with a USB cable gets root)
# Optional:
#   ANDROID_SYSTEM=dir              output of device/extract-android-blobs.sh (Wi-Fi)
#   DESKTOP=0                       skip Xorg/XFCE (default: 1)
# Needs out/kernel from kernel/build.sh. Output: out/rootfs.tar.gz, out/initramfs.cpio.gz
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-/var/tmp/sm-t280deb-rootfs}
ROOT="$WORK/rootfs"
OUT="$REPO/out"
F="$REPO/rootfs/files"
DESKTOP=${DESKTOP:-1}
BRINGUP=${BRINGUP:-0}
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ -f "${SSH_PUBKEY:-}" ] || { echo "set SSH_PUBKEY to your public key file"; exit 1; }
[ -n "${USER_PASSWORD:-}" ] || [ "$BRINGUP" = 1 ] || { echo "set USER_PASSWORD (or BRINGUP=1)"; exit 1; }
KREL=$(strings "$OUT/kernel/Image" | sed -n 's/^Linux version \([^ ]*\) .*/\1/p' | head -1)
[ -n "$KREL" ] || { echo "build the kernel first (kernel/build.sh)"; exit 1; }

# Ubuntu 26.04's uutils "install -D" replaces symlinked parents such as
# lib -> usr/lib with real directories; create parents with mkdir -p instead.
put() { mkdir -p "$(dirname "${@: -1}")"; install "$@"; }

PKGS=sysvinit-core,sysv-rc,initscripts,orphan-sysvinit-scripts,udev,kmod,procps,iproute2,ifupdown,iputils-ping,openssh-server,sudo,dnsmasq-base,wpasupplicant,iw,wireless-regdb,ca-certificates,nano,less,busybox-static,e2fsprogs,util-linux,ntpsec-ntpdate,locales,tzdata
[ "$DESKTOP" = 1 ] && PKGS=$PKGS,xserver-xorg-core,xserver-xorg-video-fbdev,xserver-xorg-input-libinput,xserver-xorg-legacy,xinit,x11-xserver-utils,xinput,xfce4-session,xfwm4,xfce4-panel,xfdesktop4,xfce4-settings,xfce4-terminal,thunar,dbus-x11,onboard,onboard-data,gsettings-desktop-schemas,at-spi2-core,gir1.2-atspi-2.0,xdg-utils,libglib2.0-bin,dconf-gsettings-backend,dconf-service,wpagui,elementary-xfce-icon-theme,qt5-gtk-platformtheme,fonts-dejavu-core,fonts-nanum,adwaita-icon-theme

# Never delete through leftover bind mounts (/dev, /proc, /sys) of an interrupted run.
if grep -q " $ROOT/" /proc/mounts; then
    echo "mounts left under $ROOT (interrupted build?); unmount them first:" >&2
    grep " $ROOT/" /proc/mounts | cut -d' ' -f2 >&2
    exit 1
fi
rm -rf --one-file-system "$ROOT"; mkdir -p "$WORK" "$OUT"
mmdebstrap --arch=armhf --variant=minbase --aptopt='APT::Install-Recommends "false"' \
    --components=main,contrib,non-free-firmware --include="$PKGS" \
    trixie "$ROOT" http://deb.debian.org/debian

# Identity and the "debian" user
echo sm-t280 > "$ROOT/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tsm-t280\n::1\tlocalhost ip6-localhost ip6-loopback\n' > "$ROOT/etc/hosts"
chroot "$ROOT" useradd -m -s /bin/bash -G sudo,video,audio,input,netdev debian
chroot "$ROOT" passwd -l root > /dev/null
if [ -n "${USER_PASSWORD:-}" ]; then
    echo "debian:$USER_PASSWORD" | chroot "$ROOT" chpasswd
else
    chroot "$ROOT" passwd -l debian > /dev/null
fi
install -d -m 700 -o 1000 -g 1000 "$ROOT/home/debian/.ssh"
install -m 600 -o 1000 -g 1000 "$SSH_PUBKEY" "$ROOT/home/debian/.ssh/authorized_keys"
cat > "$ROOT/etc/ssh/sshd_config.d/sm-t280.conf" <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
rm -f "$ROOT"/etc/ssh/ssh_host_*   # generated on first boot by sm-t280-usb

# USB serial console (CDC ACM)
if [ "$BRINGUP" = 1 ]; then
    echo 'debian ALL=(ALL) NOPASSWD:ALL' > "$ROOT/etc/sudoers.d/90-bringup"; chmod 440 "$ROOT/etc/sudoers.d/90-bringup"
    GETTY='/sbin/agetty --autologin debian -L 115200 ttyGS0 vt100'
else
    GETTY='/sbin/agetty -L 115200 ttyGS0 vt100'
fi
printf '\n# SM-T280 USB serial console\nGS0:2345:respawn:%s\n' "$GETTY" >> "$ROOT/etc/inittab"

# Filesystems
cat > "$ROOT/etc/fstab" <<'EOF'
PARTLABEL=userdata  /     ext4  defaults,noatime  0 1
tmpfs               /tmp  tmpfs nosuid,nodev      0 0
EOF

# USB gadget + Wi-Fi services
install -m 755 "$F/usb/sm-t280-usb" "$ROOT/etc/init.d/sm-t280-usb"
install -m 755 "$F/wifi/sm-t280-wifi" "$ROOT/etc/init.d/sm-t280-wifi"
put -m 755 "$F/wifi/udhcpc.script" "$ROOT/etc/udhcpc/default.script"
install -m 600 "$F/wifi/wpa_supplicant-wlan0.conf" "$ROOT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
install -m 644 "$F/wifi/50-ping.conf" "$ROOT/etc/sysctl.d/50-ping.conf"
install -m 755 "$F/wifi/wpa-action.sh" "$ROOT/etc/wpa_supplicant/action-wlan0.sh"
chroot "$ROOT" update-rc.d sm-t280-usb defaults > /dev/null
chroot "$ROOT" update-rc.d sm-t280-wifi defaults > /dev/null
if [ -d "${ANDROID_SYSTEM:-/nonexistent}/bin" ]; then
    cp -a "$ANDROID_SYSTEM" "$ROOT/system"
    chown -R root:root "$ROOT/system"
else
    echo "NOTE: ANDROID_SYSTEM not set - Wi-Fi firmware loader not included" >&2
fi

# Kernel module (Wi-Fi driver)
put -m 644 "$OUT/kernel/sprdwl.ko" "$ROOT/lib/modules/$KREL/extra/sprdwl.ko"
chroot "$ROOT" depmod -a "$KREL" 2>/dev/null

# Display: panel refresh helper, Xorg fbdev (rotated 180), XFCE session
install -m 755 "$OUT/kernel/fbpan" "$ROOT/usr/local/sbin/fbpan"
if [ "$DESKTOP" = 1 ]; then
    install -m 755 "$F/display/sm-t280-display" "$ROOT/etc/init.d/sm-t280-display"
    put -m 644 "$F/display/10-sm-t280-fbdev.conf" "$ROOT/etc/X11/xorg.conf.d/10-sm-t280-fbdev.conf"
    install -m 644 "$F/display/20-sm-t280-touch.conf" "$ROOT/etc/X11/xorg.conf.d/20-sm-t280-touch.conf"
    install -m 644 "$F/display/Xwrapper.config" "$ROOT/etc/X11/Xwrapper.config"
    put -m 644 -o 1000 -g 1000 "$F/display/onboard-autostart.desktop" \
        "$ROOT/home/debian/.config/autostart/onboard.desktop"
    chown -R 1000:1000 "$ROOT/home/debian/.config"
    install -m 644 "$F/display/90_sm-t280-onboard.gschema.override" "$ROOT/usr/share/glib-2.0/schemas/"
    chroot "$ROOT" glib-compile-schemas /usr/share/glib-2.0/schemas
    # Orientation switcher (portrait / landscape), also offered in the XFCE menu
    install -m 755 "$F/display/sm-t280-rotate" "$ROOT/usr/local/sbin/sm-t280-rotate"
    visudo -c -q -f "$F/display/91-sm-t280-rotate.sudoers"
    install -m 440 "$F/display/91-sm-t280-rotate.sudoers" "$ROOT/etc/sudoers.d/91-sm-t280-rotate"
    install -m 644 "$F"/display/sm-t280-rotate-*.desktop "$ROOT/usr/share/applications/"
    echo portrait > "$ROOT/etc/sm-t280-rotation"
    # Wi-Fi in the panel: wpa_gui tray applet (DHCP is run by the wpa_cli action script)
    install -m 644 -o 1000 -g 1000 "$F/wifi/wpa_gui-autostart.desktop" "$ROOT/home/debian/.config/autostart/wpa_gui.desktop"
    put -m 644 -o 1000 -g 1000 "$F/display/xsettings.xml"         "$ROOT/home/debian/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
    chown -R 1000:1000 "$ROOT/home/debian/.config"
    chroot "$ROOT" update-rc.d sm-t280-display defaults > /dev/null
fi

# Package sources
cat > "$ROOT/etc/apt/sources.list" <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free-firmware
EOF
echo "SM-T280deb $(date -u +%F) kernel $KREL" > "$ROOT/etc/sm-t280deb-build"

# --xattrs keeps file capabilities if the extracting tar supports them
tar -C "$ROOT" --numeric-owner --xattrs -czf "$OUT/rootfs.tar.gz" .
echo "rootfs: $(du -sh "$ROOT" | cut -f1) -> $(du -h "$OUT/rootfs.tar.gz" | cut -f1)"
ROOTFS="$ROOT" "$REPO/rootfs/build-initramfs.sh"
