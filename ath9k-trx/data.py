from __future__ import print_function
from scapy.all import ( Dot11,
                        Dot11Beacon,                        
                        Dot11Elt,
                        RadioTap,
                        sendp,
                        raw,
                        hexdump,
                        Dot11FCS,
                        )
import os

iface = 'wlan0'

bc_mac = 'ff:ff:ff:ff:ff:ff'
bssid = 'b4:ee:b4:b7:0b:3c'
tx_mac = 'b4:ee:b4:b7:0b:3c'
rx_mac = 'b4:ee:b4:b7:08:f4'

# (2,RATE,1), (15,TX_FLAGS,2), (17,DATA_RETRIES,1)
radiotap_bga = (b'\x00\x00' b'\x0d\x00' b'\x04\x80\x02\x00' b'\x02' b'\x00\x00\x00' b'\x00')
# (15,TX_FLAGS,2), (17,DATA_RETRIES,1), (19,MCS,3(known,flags,mcs))
radiotap_ht  = (b'\x00\x00' b'\x0e\x00' b'\x00\x80\x0a\x00' b'\x00\x00' b'\x00' b'\x07\x00\x05')

data = ('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff')

mpdu_header = Dot11(type=2, subtype=0, addr1=rx_mac, addr2=tx_mac, addr3=bssid)

frame = radiotap_ht/mpdu_header/data

sendp(frame, iface=iface, inter=1.000, loop=1)
