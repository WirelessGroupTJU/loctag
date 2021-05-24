from BinsUtils import *
from Dot11Utils import *

x_phy_hdr = '1111111111111111'
r_phy_hdr = '0000000000000000'
x_body = '0000000000000000'
r_body = '0000001000011000'

# 发送端
x_fcs = crc32(x_body)
x_b = x_phy_hdr+x_body+x_fcs
x_w = scrambler(x_b, init_state=0x7f)
x_c = dbpsk_encoder(x_w, init_state=1)

# 标签
r_fcs = crc32(r_body, init_state=0x00, out_xor_val=0x00)
r_b = r_phy_hdr+r_body+r_fcs
r_w = scrambler(r_b, init_state=0x00)
r_c = dbpsk_encoder(r_w, init_state=0)

# 接收端
y_c = xor_bins(x_c, r_c)
y_w = descrambler(y_c, init_state=0x00)
y_b = dbpsk_decoder(y_w, init_state=0)
y_phy_hdr, y_body, y_fcs = y_b[:len(x_phy_hdr)], y_b[len(x_phy_hdr):-32], y_b[-32:]

# 打印结果
print('x:', 'phy_hdr:' ,format_bins(x_phy_hdr) , 'body:', format_bins(x_body), 'fcs:', format_bins(x_fcs))
print('r:', 'phy_hdr:' ,format_bins(r_phy_hdr) , 'body:', format_bins(r_body), 'fcs:', format_bins(r_fcs))
print('y:', 'phy_hdr:' ,format_bins(y_phy_hdr) , 'body:', format_bins(y_body), 'fcs:', format_bins(y_fcs), 'fcs is correct' if crc32(y_body)==y_fcs else 'fcs is incorrect')


"""
初始状态的影响（根据论文式3-17易得）：
```latex
\begin{align}
    \begin{split} \label{eq:ch2MimoXYH}
        \begin{array}{cccc}
            r_b[0]=y_b[0]+x_b[0] & + x_c[-1]+y_c[-1] &+x_w[-7]+y_w[-7] + x_w[-4]+y_w[-4] \\
            r_b[1]=y_b[1]+x_b[1] &                   &+x_w[-6]+y_w[-6] + x_w[-3]+y_w[-3] \\
            r_b[2]=y_b[2]+x_b[2] &                   &+x_w[-5]+y_w[-5] + x_w[-2]+y_w[-2] \\
            r_b[3]=y_b[3]+x_b[3] &                   &+x_w[-4]+y_w[-4] + x_w[-1]+y_w[-1] \\
            r_b[4]=y_b[4]+x_b[4] & + x_c[-1]+y_c[-1] &+x_w[-3]+y_w[-3] \\
            r_b[5]=y_b[5]+x_b[5] &                   &+x_w[-2]+y_w[-2] \\
            r_b[6]=y_b[6]+x_b[6] &                   &+x_w[-1]+y_w[-1] \\
            r_b[7]=y_b[7]+x_b[7] & + x_c[-1]+y_c[-1] & ~ \\
            r_b[8]=y_b[8]+x_b[8] &                   & ~ \\
            $\vdots$             &                   & ~ \\
            r_b[n]=y_b[n]+x_b[n] &                   & ~
        \end{array}
    \end{split}
\end{align}
```
"""