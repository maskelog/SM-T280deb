#!/bin/sh
# wpa_cli action script: (re)run DHCP whenever wlan0 associates, so networks
# chosen from the panel applet (wpa_gui) get an address. Args: IFACE EVENT
IFACE=$1
PID=/run/udhcpc-$IFACE.pid
case "$2" in
CONNECTED)
    [ -f $PID ] && kill "$(cat $PID)" 2>/dev/null
    busybox udhcpc -i "$IFACE" -s /etc/udhcpc/default.script -b -p $PID -t 10 >/dev/null 2>&1
    ;;
DISCONNECTED)
    [ -f $PID ] && kill "$(cat $PID)" 2>/dev/null
    ip -4 addr flush dev "$IFACE"
    ;;
esac
