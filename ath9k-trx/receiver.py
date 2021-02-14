from __future__ import print_function
from scapy.all import ( Dot11, Dot11Beacon, Dot11Elt, Dot11EltVendorSpecific, RadioTap,
                        sendp, sniff,
                        raw, hexdump,
                        )
import os, sys, struct

class Tag:

    def __init__(self, id):
        self.id = id

class Receiver:

    def __init__(self, iface='wlan0'):
        self.iface = iface   
        self.bc_mac = 'ff:ff:ff:ff:ff:ff'
        self.bssid =  'b4:ee:b4:b7:0b:3c'
        self.tx_mac = 'b4:ee:b4:b7:0b:3c'
        self.rx_mac = 'b4:ee:b4:b7:08:f4'     
    
    def get_ht_radiotap(self, mcs=0):
        # (15,TX_FLAGS,2), (17,DATA_RETRIES,1), (19,MCS,3(known,flags,mcs))
        return (b'\x00\x00' b'\x0e\x00' b'\x00\x80\x0a\x00' b'\x00\x00' b'\x00' b'\x07\x00\x05')
    def send_req_frame(self, inter=0.010, loop=0):
        # packet duration is ?
        data = ('LOCTAG-REQ')
        mpdu_header = Dot11(type=2, subtype=0, addr1=self.tx_mac, addr2=self.rx_mac, addr3=self.bssid)
        frame = self.get_ht_radiotap(mcs=0)/mpdu_header/data
        sendp(frame, iface=self.iface, inter=inter, loop=loop, verbose=False)

    def PacketHandler(self, pkt):
        rt = pkt.getlayer(RadioTap)
        rate = rt.Rate
        rssi = rt.dBm_AntSignal

        if pkt.haslayer(Dot11Beacon):
            ssid = pkt.info
            timestamp = pkt.getlayer(Dot11Beacon).timestamp
            data = pkt.getlayer(Dot11EltVendorSpecific).info if pkt.haslayer(Dot11EltVendorSpecific) else b''

            if ssid in self.tags:
                self.tags[ssid][0] = self.tags[ssid][0] + 1
                self.tags[ssid][1].append((rssi, timestamp, data))
            else:
                self.tags[ssid] = [1, [(rssi, timestamp, data)]]
            print(self.rx_cnt, rate, rssi, ssid, timestamp, data)
        
        else:
            if rt.MCS:
                print(self.rx_cnt, rt.MCS_index, rssi)
            else:
                print(self.rx_cnt, rate, rssi)
        self.rx_cnt = self.rx_cnt+1

    def run(self, isFilter=True, send_pattern=(6, 1, 2), time=0):
        self.time = time
        self.filter_exp = "ether host %s"%self.tx_mac if isFilter else ''

        self.rx_cnt = 0
        self.tags = {} # tag_id: [counter, [(rssi, timestamp, data)]]
        # Send transmission request to Tx
        send_req_frame()
        # Receive packets from Tx
        self.num = send_pattern[0]*(send_pattern[1]+send_pattern[2])
        sniff(iface=self.iface, filter=self.filter_exp, prn=self.PacketHandler, count=self.num)

if __name__ == "__main__":
    receiver = Receiver(iface='wlan1')
    receiver.run(isFilter=True)
