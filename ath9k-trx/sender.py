from __future__ import print_function
from scapy.all import ( Dot11,
                        Dot11Beacon,
                        Dot11Elt,
                        Dot11EltVendorSpecific,
                        RadioTap,
                        sendp,
                        sniff,
                        raw,
                        hexdump,
                        )
import os, struct

class Sender:
    def __init__(self, iface='wlan0'):
        self.iface = iface
        self.bc_mac = 'ff:ff:ff:ff:ff:ff'
        self.bssid =  'b4:ee:b4:b7:0b:3c'
        self.tx_mac = 'b4:ee:b4:b7:0b:3c'
        self.rx_mac = 'b4:ee:b4:b7:08:f4'
    
    def get_legacy_radiotap(self, ht=False, rate=1):
        """rate in Mbps"""
        # (2,RATE,1), (15,TX_FLAGS,2), (17,DATA_RETRIES,1)
        return (b'\x00\x00' b'\x0d\x00' b'\x04\x80\x02\x00' b'\x02' b'\x00\x00\x00' b'\x00')

    def get_ht_radiotap(self, mcs=0):
        # (15,TX_FLAGS,2), (17,DATA_RETRIES,1), (19,MCS,3(known,flags,mcs))
        return (b'\x00\x00' b'\x0e\x00' b'\x00\x80\x0a\x00' b'\x00\x00' b'\x00' b'\x07\x00\x05')
    
    def send_beacon_frame(self, inter=0.010, loop=0):
        # packet duration is 736us in 1Mbps
        SSID = '000000-0000-0000'
        mpdu_header = Dot11(type=0, subtype=8, addr1=self.bc_mac, addr2=self.tx_mac, addr3=self.bssid)
        beacon = Dot11Beacon(timestamp=0, beacon_interval=100, cap=0)
        essid = Dot11Elt(ID='SSID',info=SSID, len=len(SSID))
        vendor_data = Dot11EltVendorSpecific(len=None, oui=0x544a55, info=(b'\x00'+b'\x00'*8))
        frame = self.get_legacy_radiotap(rate=1)/mpdu_header/beacon/essid/vendor_data
        # hexdump(raw(frame))
        sendp(frame, iface=self.iface, inter=inter, loop=loop, verbose=False)

    def send_data_frame(self, inter=0.010, loop=0):
        # packet duration is ?
        data = ('LOCTAG')
        mpdu_header = Dot11(type=2, subtype=0, addr1=self.rx_mac, addr2=self.tx_mac, addr3=self.bssid)
        frame = self.get_ht_radiotap(mcs=0)/mpdu_header/data
        sendp(frame, iface=self.iface, inter=inter, loop=loop, verbose=False)
    
    def send_end_frame(self, inter=0.010, loop=0):
        # packet duration is ?
        data = ('LOCTAG-END')
        mpdu_header = Dot11(type=2, subtype=0, addr1=self.rx_mac, addr2=self.tx_mac, addr3=self.bssid)
        frame = self.get_ht_radiotap(mcs=0)/mpdu_header/data
        sendp(frame, iface=self.iface, inter=inter, loop=loop, verbose=False)
    
    def PacketHandler(self, packet):
        pass

    def run(self, isPassive=True, send_pattern=(6, 1, 2)):
        filter_exp = "ether host %s"%self.rx_mac
        cnt = 0
        while True:
            # Waiting for Rx transmission request
            if isPassive:
                sniff(iface=self.iface, filter=filter_exp, prn=self.PacketHandler, count=1)
            cnt = cnt + 1
            print('start %d'%cnt)
            # Start a round of transmission
            for i in range(send_pattern[0]):
                for j in range(send_pattern[1]):
                    self.send_beacon_frame()
                for j in range(send_pattern[2]):
                    self.send_data_frame()
            for i in range(2):
                self.send_end_frame()

if __name__ == "__main__":    
    sender = Sender(iface='wlan0')
    sender.run(isPassive=True)
