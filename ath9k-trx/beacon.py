from __future__ import print_function
from scapy.all import ( Dot11,
                        Dot11Beacon,
                        Dot11Elt,
                        Dot11EltVendorSpecific,
                        RadioTap,
                        sendp,
                        raw,
                        hexdump,
                        )
import os, struct

iface = 'wlan1'  #os.environ.get('WLDEV_NAME')

bc_mac = 'ff:ff:ff:ff:ff:ff'
bssid = 'b4:ee:b4:b7:0b:3c'
tx_mac = 'b4:ee:b4:b7:0b:3c'
rx_mac = 'b4:ee:b4:b7:08:f4'

# (2,RATE,1), (15,TX_FLAGS,2), (17,DATA_RETRIES,1)
radiotap_bga = (b'\x00\x00' b'\x0d\x00' b'\x04\x80\x02\x00' b'\x02' b'\x00\x00\x00' b'\x00')
# (15,TX_FLAGS,2), (17,DATA_RETRIES,1), (19,MCS,3(known,flags,mcs))
radiotap_ht  = (b'\x00\x00' b'\x0e\x00' b'\x00\x80\x0a\x00' b'\x00\x00' b'\x00' b'\x07\x00\x05')

SSID = '000000-0000-0000'

mpdu_header = Dot11(type=0, subtype=8, addr1=bc_mac, addr2=tx_mac, addr3=bssid)

beacon = Dot11Beacon(timestamp=0, beacon_interval=100, cap=0)
essid = Dot11Elt(ID='SSID',info=SSID, len=len(SSID))
vendor_data = Dot11EltVendorSpecific(len=None, oui=0x544a55, info=(b'\x00'+b'\x00'*8))

frame = radiotap_bga/mpdu_header/beacon/essid/vendor_data

hexdump(raw(mpdu_header/beacon/essid/vendor_data))

sendp(frame, iface=iface, inter=0.100, loop=1)
