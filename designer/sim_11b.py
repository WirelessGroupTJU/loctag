from BinsUtils import *
from Dot11Utils import *

# 24: beacon timestamp (index start from 0)
# 32: beacon interval
# 34: cap
# 36: 00h  37: 10h  38-53: 000000-0000-0000
# 54: DDh  55: 0Ch  56-58: 'TJU'(OUI)  59,60-67: 0h
# 68-71: FCS
# 载包
start_pos = 34
tx11b_pkt = (b'\x80\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xB4\xEE\xB4\xB7\x0B\x3C'
b'\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\xFA\x23\xEB\x27\x01\x00\x00\x00'
b'\x64\x00\x00\x00\x00\x10000000-000'
b'0-0000\xDD\x0C\x54\x4A\x55\x00\x00\x00\x00\x00'
b'\x00\x00\x00\x00') #FCS: 2A 8C 26 F2 :01010100001100010110010001001111
# 期望的数据
rx11b_pkt = (b'\x80\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xB4\xEE\xB4\xB7\x0B\x3C'
b'\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\xFA\x23\xEB\x27\x01\x00\x00\x00'
b'\x64\x00\x00\x00\x00\x10LOCTAG-031'
b'2-0001\xDD\x0C\x54\x4A\x55\x00\x00\x00\x00\x00'
b'\x00\x00\x00\x00')

ta11b_dat = xor_bytes(tx11b_pkt, rx11b_pkt)[start_pos:]

tx_0 = bytes2bins(tx11b_pkt, msb_first=False)
tx_crc32 = crc32(tx_0)
tx_0_with_crc = tx_0+tx_crc32
tx_1_with_crc = scrambler(tx_0_with_crc)
tx_2_with_crc = dbpsk_encoder(tx_1_with_crc)

# Backscatter
dx_0 = bytes2bins(ta11b_dat, msb_first=False)
dx_crc32 = crc32(dx_0)
dx_crc32_0 = crc32(('0'*len(dx_0)))
dx_0_with_crc = dx_0 + xor_bins(dx_crc32, dx_crc32_0)
dx_1_with_crc = scrambler(dx_0_with_crc, init_state=0x00)
dx_2_with_crc = dbpsk_encoder(dx_1_with_crc, init_state=0)
dx_3_with_crc = '0'*(start_pos*8) + dx_2_with_crc  # filling

rx_2_with_crc = xor_bins(tx_2_with_crc, dx_3_with_crc)

rx_1_with_crc = descrambler(rx_2_with_crc)
rx_0_with_crc = dbpsk_decoder(rx_1_with_crc)
rx_0 = rx_0_with_crc[:-32]
rx_crc32 = rx_0_with_crc[-32:]
rx_crc32_cal = crc32(rx_0)

print('tx:')
print(format_bins_to_hex(tx_0_with_crc, msb_first=False,nol=32))
print('rx:')
print(format_bins_to_hex(rx_0_with_crc, msb_first=False,nol=32))
print('dx:')
print(format_bins_to_hex(dx_0_with_crc, msb_first=False,nol=32))
# print(format_bins_to_hex(dx_2_with_crc, msb_first=False,nol=32))
print('%s = CRC32(D)+CRC32(0) = %s ^ %s'% (
        format_bins_to_hex(xor_bins(dx_crc32, dx_crc32_0), msb_first=False, nol=32),
        format_bins_to_hex(dx_crc32, msb_first=False, nol=32),
        format_bins_to_hex(dx_crc32_0, msb_first=False, nol=32)
    ))

print('rx-cal:', format_bins_to_hex(rx_crc32_cal, msb_first=False,nol=32))

print(format_bins(dx_0_with_crc))
print(format_bins(dx_1_with_crc))
print(format_bins(dx_2_with_crc))
