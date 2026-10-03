# GPU (Mali-400 MP) — OpenGL ES 2.0 on fbdev

The SC7730 has a Mali-400 MP GPU. The vendor kernel ships ARM's r6p0 driver
(user/kernel API 800), but the public Linux userspace builds of the Mali blob
(e.g. bootlin/mali-blobs r6p2, r8p1) need API 900. `kernel/build.sh` therefore
replaces `drivers/gpu/mali400` with ARM's GPL **r6p2-01rel0** kernel driver
(downloaded and hash-checked by `kernel/fetch-sources.sh`) plus
`kernel/patches/0011-mali-r6p2-sc8830.patch` (the vendor sc8830 clock/power
glue, and memory validation limited to the fb0 range).

What works: full-screen OpenGL ES 2.0 apps through the **fbdev** EGL, while X is
stopped. The XFCE desktop itself still uses software rendering (accelerating X
would need the X11 blob, UMP and a DRI2 X driver; the gain for XFCE is small).

## Userspace (not in this repository)

The Mali userspace library is proprietary (ARM EULA) and is not shipped here.
Get the **armhf, fbdev** build of `libMali.so` r6p2 (for example
the hard-float `libMali.so` under `r6p2/arm/fbdev/` in
https://github.com/bootlin/mali-blobs) and its `include/` headers, then on the
tablet:

```sh
sudo mkdir -p /opt/mali/lib && sudo cp libMali.so /opt/mali/lib/
cd /opt/mali/lib && for l in libEGL.so libEGL.so.1 libGLESv2.so libGLESv2.so.2 \
    libGLESv1_CM.so libGLESv1_CM.so.1; do sudo ln -sf libMali.so $l; done
```

The blob is marked as needing an executable stack, which glibc ≥ 2.41 refuses
for `dlopen()`. Either run programs with
`GLIBC_TUNABLES=glibc.rtld.execstack=2`, or clear the flag on your copy
(`patchelf --clear-execstack libMali.so`).

## Running a GLES program

```sh
sudo /etc/init.d/sm-t280-display stop        # X and the fbpan refresher
sudo env GLIBC_TUNABLES=glibc.rtld.execstack=2 LD_LIBRARY_PATH=/opt/mali/lib ./app
sudo /etc/init.d/sm-t280-display start
```

`/dev/mali` is root-only by default; add a udev rule if a normal user should
use the GPU. The fbdev EGL presents with `FBIOPAN_DISPLAY`, which is also what
refreshes the command-mode panel, so no `fbpan` loop is needed while a GLES app
runs. Frame rate is capped at the panel's 60 Hz.

## glmark2

Upstream glmark2 has no fbdev flavor; `tools/glmark2-fbdev.patch` adds
`fbdev-glesv2` (a native state that hands the EGL an `fbdev_window` the size of
fb0):

```sh
sudo apt install meson ninja-build g++ pkg-config libpng-dev libjpeg-dev git
git clone https://github.com/glmark2/glmark2 && cd glmark2
git apply /path/to/SM-T280deb/tools/glmark2-fbdev.patch
meson setup build -Dflavors=fbdev-glesv2 && ninja -C build
sudo env GLIBC_TUNABLES=glibc.rtld.execstack=2 LD_LIBRARY_PATH=/opt/mali/lib \
    build/src/glmark2-es2-fbdev --data-path data --fullscreen
```
