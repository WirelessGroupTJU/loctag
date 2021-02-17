from __future__ import print_function
from scapy.all import ( Dot11, Dot11Beacon, Dot11Elt, Dot11EltVendorSpecific, RadioTap,
                        sendp, sniff,
                        raw, hexdump,
                        )
import os, sys, struct, signal, time

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
            if pkt.haslayer(Dot11EltVendorSpecific):
                data = pkt.getlayer(Dot11EltVendorSpecific).info
                tag_adc = data[4] if isinstance(data[4], int) else ord(data[4])
            else:
                tag_adc = 0

            if ssid[6]==b'-':
                self.records.append((ssid, rssi, timestamp, tag_adc))
                if not hasattr(self, 'file') or not self.file:
                    self.file = open(self.filename, 'w')
                for record in self.records:
                    self.file.write('%s,%d,%d,%d\n'%(record[0],record[1],record[2],record[3]))
                tag_rss = (tag_adc&0xff)*0.333 - 65.4
                print('%04d %d %3.1f %4d dBm %s %.6f %5.1f dBm' %(self.rx_cnt, rt.ChannelFrequency, rate, rssi, ssid, timestamp/1.0e6, tag_rss))
        
        else:
            if rt.MCS_index is not None:
                print('%04d %d %d %d dBm' %(self.rx_cnt, rt.ChannelFrequency, rt.MCS_index, rssi))
            else:
                print('%04d %d %3.1f %d dBm' %(self.rx_cnt, rt.ChannelFrequency, rate, rssi))
        self.rx_cnt = self.rx_cnt+1

    def run(self, isFilter=True, send_pattern=(0, 1, 2), timelong=0):
        self.time = timelong
        self.filter_exp = "ether host %s"%self.tx_mac if isFilter else ''
        self.filename = time.strftime("tag-records-%Y%m%d%H%M%S.txt", time.localtime())
        self.rx_cnt = 0
        self.records = []  # [(tag_id, rssi, timestamp, tag_adc)]
        # Send transmission request to Tx
        self.send_req_frame()
        # Receive packets from Tx
        self.num = send_pattern[0]*(send_pattern[1]+send_pattern[2])
        try:
            sniff(iface=self.iface, filter=self.filter_exp, prn=self.PacketHandler, count=self.num)
        except KeyboardInterrupt:
            print('Interrupted by user')
        finally:
            self.file.close()
            print('file %s write'%self.filename)

if __name__ == "__main__":
    receiver = Receiver(iface='wlan0')
    receiver.run(isFilter=True, send_pattern=(0, 1, 2))
