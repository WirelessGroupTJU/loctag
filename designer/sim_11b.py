from BinsUtils import *
from Dot11Utils import *

# 24: beacon timestamp (index start from 0)
# 32: beacon interval
# 34: cap
# 36: 00h  37: 10h  38-53: 000000-0000-0000
# 54: DDh  55: 0Ch  56-58: 'TJU'(OUI)  59,60-67: 0h
# 68-71: FCS
# 激励Beacon帧Body
x_phy_hdr = '1111111111111111' # 仅做示例，实际的x_phy_hdr为144+48=192比特
r_phy_hdr = '0000000000000000' # 仅做示例，实际的x_phy_hdr为144+48=192比特
x_body_bytes = (b'\x80\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xB4\xEE\xB4\xB7\x0B\x3C'
b'\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\xFA\x23\xEB\x27\x01\x00\x00\x00'
b'\x64\x00\x00\x00\x00\x0C000000-'
b'00000\xDD\x0C\x54\x4A\x55\x00\x00\x00\x00\x00'
b'\x00\x00\x00\x00')
# 期望的数据
y_body_bytes = (b'\x80\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xB4\xEE\xB4\xB7\x0B\x3C'
b'\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\xFA\x23\xEB\x27\x01\x00\x00\x00'
b'\x64\x00\x00\x00\x00\x0CLOCTAG-'
b'10000\xDD\x0C\x54\x4A\x55\x00\x00\x00\x00\x00'
b'\x00\x00\x00\x00')

r_body_bytes = xor_bytes(x_body_bytes, y_body_bytes)

x_body = bytes2bins(x_body_bytes, msb_first=False)
x_fcs = crc32(x_body)
x_b = x_phy_hdr+x_body+x_fcs
x_w = scrambler(x_b, init_state=0x01)
x_c = dbpsk_encoder(x_w, init_state=0)

# Backscatter
r_body = bytes2bins(r_body_bytes, msb_first=False)
r_fcs = crc32(r_body, init_state=0x00, out_xor_val=0x00)
r_b = r_phy_hdr+r_body + r_fcs
r_w = scrambler(r_b, init_state=0x00)
r_c = dbpsk_encoder(r_w, init_state=0)

y_c = xor_bins(x_c, r_c)

y_w = descrambler(y_c, init_state=0x00)
y_b = dbpsk_decoder(y_w, init_state=0)
y_phy_hdr, y_body, y_fcs = y_b[:len(x_phy_hdr)], y_b[len(x_phy_hdr):-32], y_b[-32:]

fcs_check_result_str = 'fcs is correct' if crc32(y_body)==y_fcs else 'fcs is incorrect'

# 用于计算标签数据，检查FCS
print('x:')
print(format_bins_to_hex(x_b[len(x_phy_hdr):], msb_first=False,nol=32), '   fcs:', format_bins(x_fcs))
print('y:')
print(format_bins_to_hex(y_b[len(x_phy_hdr):], msb_first=False,nol=32), '   fcs:', format_bins(y_fcs), fcs_check_result_str)
print('r:')
print(format_bins_to_hex(r_b[len(x_phy_hdr):], msb_first=False,nol=32), '   fcs:', format_bins(r_fcs))
print()

# 用于调试FPGA程序
print('r_b:\n'+format_bins(r_b[len(x_phy_hdr):]))
print('r_w:\n'+format_bins(r_w[len(x_phy_hdr):]))
print('r_c:\n'+format_bins(r_c[len(x_phy_hdr):]))
