#!/bin/sh
# Run ON THE TABLET as root: download the Mali-400 r6p2 fbdev userspace
# (OpenGL ES 2.0 / EGL) from bootlin/mali-blobs and install it to /opt/mali.
#
# The library is ARM/Allwinner proprietary software under its own EULA
# ("EULA for Mali 400MP _AW.pdf" in that repository); it is not part of this
# project. By running this script you download it yourself and accept that
# EULA. Files are pinned to one commit and checked against sha256.
#
# Afterwards run GLES programs (with X stopped, see docs/gpu.md) as:
#   mali-run ./program
set -eu
[ "$(id -u)" = 0 ] || { echo "run as root (sudo $0)"; exit 1; }
COMMIT=418f55585e76f375792dbebb3e97532f0c1c556d
BASE=https://raw.githubusercontent.com/bootlin/mali-blobs/$COMMIT
DEST=/opt/mali
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
while read -r sha path; do
    mkdir -p "$(dirname "$path")"
    curl -fsSL --retry 3 -o "$path" "$BASE/$path"
    echo "$sha  $path" | sha256sum -c --quiet
done <<'LIST'
3207beb7b19a0d465c24d9d591be042a36a359caf4e44061ded4f3a17cffbfd5 r6p2/arm/fbdev/libMali.so
c0fde924ff3917d762b126cf4929d1d98d73696440f1f795eefec7df5d6eb454 include/fbdev/EGL/egl.h
b4076eff9001077e2fcc23eb07198a88788aeb40e09a55a8c3f3b23f8849b218 include/fbdev/EGL/eglext.h
f7b9bec62d5ae444d84a76c9da231a31d77ac39da7b0755433775c204a80e02f include/fbdev/EGL/eglplatform.h
d1d865d17a2d6bf1ed819b26264f3f4ea26d0aa0f463ac24c40cd94a86d3d26d include/fbdev/EGL/fbdev_window.h
6bf76f93ead775ba2b3f1586cf376bc996f3c077cdee06dcc04988b757944de7 include/fbdev/GLES2/gl2.h
e78d3824e1d71f8a463bad2047fb8b873f735ba7cacbd8ef74cc398b5593729a include/fbdev/GLES2/gl2ext.h
d9ea63aa7ecc16f06e8321674702ceaacaf0a81777c616a0a3f859f21ce1c085 include/fbdev/GLES2/gl2platform.h
509bf4401371fa6f8a45bca49e03359e98e3e6be6a68b1578e4352b20fa56f60 include/fbdev/KHR/khrplatform.h
LIST
rm -rf "$DEST"
install -d "$DEST/lib" "$DEST/include"
install -m 644 r6p2/arm/fbdev/libMali.so "$DEST/lib/"
for l in libEGL.so libEGL.so.1 libGLESv2.so libGLESv2.so.2 libGLESv1_CM.so libGLESv1_CM.so.1; do
    ln -s libMali.so "$DEST/lib/$l"
done
cp -r include/fbdev/EGL include/fbdev/GLES2 include/fbdev/KHR "$DEST/include/"
# The blob asks for an executable stack; glibc >= 2.41 refuses that for
# dlopen() unless allowed. mali-run sets the library path and the tunable.
cat > /usr/local/bin/mali-run <<'RUN'
#!/bin/sh
# Run a program with the Mali fbdev OpenGL ES libraries from /opt/mali.
export LD_LIBRARY_PATH=/opt/mali/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export GLIBC_TUNABLES=glibc.rtld.execstack=2${GLIBC_TUNABLES:+:$GLIBC_TUNABLES}
exec "$@"
RUN
chmod 755 /usr/local/bin/mali-run
# GPU access for the video group (the desktop user is a member)
echo 'KERNEL=="mali", MODE="0660", GROUP="video"' > /etc/udev/rules.d/60-sm-t280-mali.rules
udevadm control --reload 2>/dev/null || true
[ -e /dev/mali ] && chgrp video /dev/mali && chmod 660 /dev/mali
echo "Mali r6p2 fbdev userspace installed to $DEST (build with -I$DEST/include -L$DEST/lib -lEGL -lGLESv2)"
