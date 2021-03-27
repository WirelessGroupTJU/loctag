#!/usr/bin/sudo /bin/bash
if [ $2 == a ]; then
    iw dev wlan0 set channel 11
    /usr/bin/loctag_csi "$1$2"
else
    iw dev wlan0 set channel 1
    /usr/bin/loctag_csi "$1$2"
fi
