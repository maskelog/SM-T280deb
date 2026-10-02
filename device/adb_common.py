"""Shared adb helpers. Set ADB_SERIAL if more than one device is connected."""
import os, subprocess
ADB = ['adb'] + (['-s', os.environ['ADB_SERIAL']] if os.environ.get('ADB_SERIAL') else [])

def adb(*argv, timeout=900):
    return subprocess.check_output([*ADB, *argv], timeout=timeout)

def sh(cmd, timeout=900):
    return adb('shell', cmd, timeout=timeout).decode(errors='replace')

def by_name(name):
    """Resolve a partition by its GPT name, as TWRP exposes it."""
    return sh(f'readlink /dev/block/platform/sdio_emmc/by-name/{name}').strip()

def require_twrp_on_sm_t280():
    assert adb('get-state', timeout=30).strip() == b'recovery', 'boot the tablet into TWRP first'
    dev = sh('getprop ro.product.device').strip()
    assert dev == 'gtexswifi', f'not an SM-T280 (gtexswifi): {dev!r}'
    assert int(sh('cat /sys/class/power_supply/battery/capacity').strip()) >= 30, 'charge to >= 30%'
