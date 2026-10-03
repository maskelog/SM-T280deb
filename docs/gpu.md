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

The Mali userspace library is proprietary (ARM/Allwinner EULA) and cannot be
built from source, so it is not shipped here. On the tablet, let
`tools/install-mali-userspace.sh` download it from
https://github.com/bootlin/mali-blobs (pinned commit, sha256-checked) — by
running it you accept that EULA:

```sh
sudo sh install-mali-userspace.sh
```

It installs the r6p2 hard-float fbdev `libMali.so` with its EGL/GLES2 headers
to `/opt/mali`, a `mali-run` wrapper, and a udev rule that gives the `video`
group access to `/dev/mali`. `mali-run` sets `LD_LIBRARY_PATH` and
`GLIBC_TUNABLES=glibc.rtld.execstack=2`: the blob asks for an executable stack,
which glibc >= 2.41 otherwise refuses for `dlopen()`.

## Running a GLES program

```sh
gcc app.c -I/opt/mali/include -L/opt/mali/lib -lEGL -lGLESv2 -o app
sudo /etc/init.d/sm-t280-display stop        # X and the fbpan refresher
mali-run ./app
sudo /etc/init.d/sm-t280-display start
```

The fbdev EGL presents with `FBIOPAN_DISPLAY`, which is also what refreshes
the command-mode panel, so no `fbpan` loop is needed while a GLES app runs.
Frame rate is capped at the panel's 60 Hz.

## glmark2

Upstream glmark2 has no fbdev flavor; `tools/glmark2-fbdev.patch` adds
`fbdev-glesv2` (a native state that hands the EGL an `fbdev_window` the size of
fb0):

```sh
sudo apt install meson ninja-build g++ pkg-config libpng-dev libjpeg-dev git
git clone https://github.com/glmark2/glmark2 && cd glmark2
git apply /path/to/SM-T280deb/tools/glmark2-fbdev.patch
meson setup build -Dflavors=fbdev-glesv2 && ninja -C build
mali-run build/src/glmark2-es2-fbdev --data-path data --fullscreen
```
