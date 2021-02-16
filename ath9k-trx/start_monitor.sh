#!/usr/bin/sudo /bin/bash
ip link set dev wlan0 down
iw dev wlan0 set monitor none
ip link set dev wlan0 up
if [ x$1 = x ]; then
    iw dev wlan0 set channel 11
else
    iw dev wlan0 set channel $1
