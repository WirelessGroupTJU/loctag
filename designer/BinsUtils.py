"""###############################################
# 处理由字符0和字符1组成的二进制位串的工具函数集合
###############################################"""

"""##########################################
  coding and decoding modules
##########################################"""

def crc16(bins_input):
    """Computing the CRC-16 value of input bit stream given by bin string.
    Args:
        bins_input: Bin string which the leftmost bit shall be processed first.
    Return:
        A 16-bit binstring result which the leftmost bit shall be transmitted first.
    """
    regs = 0xffff
    xor_val = 0xffff
    poly = 0x1021

    for i in range(len(bins_input)):
        if bins_input[i]=='0':
            b_in = 0x00000 
        elif bins_input[i]=='1':
            b_in = 0x10000
        else:
            raise ValueError('0 or 1 expected but {} is given'.format(bins_input[i]))
        regs <<= 1
        regs = (regs&0x0fffe) if ((regs^b_in)&0x10000)==0x00000 else ((regs^poly)&0x0ffff)
        # dbg_info(bins_input[i], bin(regs)[2:].zfill(16))
    # return regs
    return bin((regs^xor_val)&0xffff)[2:].zfill(16)

def crc32(bins_input, init_state=0xffffffff, out_xor_val=0xffffffff, isflip=False):
    """Computing the CRC-32 value of input bit stream given by bin string.
    Args:
        bins_input: Bin string which the leftmost bit shall be processed first.
    Return:
        A 32-bit binstring result which the leftmost bit shall be transmitted first.
    """
    regs = init_state
    xor_val = out_xor_val
    poly = 0x04c11db7
    # print('X', bin(poly)[2:].zfill(32))
    for i in range(len(bins_input)):
        if bins_input[i]=='0':
            b_in = 0x0
        elif bins_input[i]=='1':
            b_in = 0x1
        else:
            raise ValueError('0 or 1 expected but {} is given'.format(bins_input[i]))
        c = ((regs>>31)&0x01)
        regs <<= 1
        regs = (regs&0x0fffffffe) if (c^b_in)==0x00 else ((regs^poly)&0xffffffff)
        # print(bins_input[i], bin(regs)[2:].zfill(32))
    # return regs
    if isflip:
        return bin((~(regs^xor_val))&0xffffffff)[2:].zfill(32)
    else:
        return bin((regs^xor_val)&0xffffffff)[2:].zfill(32)

"""##########################################
  basic data transform
##########################################"""

def bytes2bins(bytes_input, msb_first=True):
    """将字节转化为由字符0和字符1表示的位串，字节内的最高位被首先传输，位串的传输顺序为从左到右 """
    if msb_first:
        return ''.join(['{:08b}'.format(it) for it in bytes_input])
    else:
        return ''.join(['{:08b}'.format(it)[::-1] for it in bytes_input])

def bins2bytes(bins_input, msb_first=True):
    """将由字符0和字符1表示的位串转化为字节，位串必须为8的整数倍 """
    assert len(bins_input)%8==0
    if msb_first:
        bytes_output = bytearray([int(bins_input[i*8:i*8+8], base=2) for i in range(len(bins_input)//8)])
    else:
        bytes_output = bytearray([int((bins_input[i*8:i*8+8:])[::-1], base=2) for i in range(len(bins_input)//8)])
    return bytes(bytes_output)

def bytes_reverse_bit_order(bytes_input):
    """逐字节地翻转字节内的位序 """
    bytes_output = bytearray([int(bin(byte)[2:].zfill(8)[::-1], base=2) for byte in bytes_input])
    return bytes(bytes_output)

def field_reverse_bit_order(field_input: int, field_byte_num):
    assert type(field_input) == int
    bin_str = bin(field_input)[2:].zfill(field_byte_num*8)[::-1]
    return bytes([int(bin_str[i*8:i*8+8], base=2) for i in range(field_byte_num)])

def xor_bins(bins_a, bins_b):
    assert len(bins_a)==len(bins_b), '{} != {}'.format(len(bins_a), len(bins_b))
    map_obj = map(lambda bit1,bit2: '0' if bit1==bit2 else '1',
        list(bins_a), list(bins_b))
    return ''.join(map_obj)

def xor_bytes(bytes_a, bytes_b):
    assert len(bytes_a)==len(bytes_b), '{} != {}'.format(len(bytes_a), len(bytes_b))
    return bins2bytes(xor_bins(bytes2bins(bytes_a,msb_first=True), bytes2bins(bytes_b,msb_first=True)),msb_first=True)

def xnor_bins(bins_a, bins_b):
    assert len(bins_a)==len(bins_b)
    map_obj = map(lambda bit1,bit2: '1' if bit1==bit2 else '0',
        list(bins_a), list(bins_b))
    return ''.join(map_obj)

"""##########################################
Formatting output
##########################################"""

def format_bytes(bytes_input, nol=16):
    """
    返回格式化的字节，输出每8位插入一个空格，bins_input长度不必须是8位的整数倍
    """
    formatted_bytes = ''
    for i in range(len(bytes_input)):
        if (i%nol==nol-1):
            formatted_bytes += '{:02x}\n'.format(bytes_input[i])
        elif (i%8==7):
            formatted_bytes += '{:02x}  '.format(bytes_input[i])
        else:
            formatted_bytes += '{:02x} '.format(bytes_input[i])
    return formatted_bytes

def format_bins(bins_input, force_align=False, msb_first=True):
    """
    返回格式化的位串，每8位插入一个空格
    """
    if force_align:
        assert len(bins_input)%8==0, 'No alignment to octet'
    octet_num = len(bins_input)//8
    formatted_bins = ''
    for i in range(octet_num):
        formatted_bins += bins_input[i*8:i*8+8]+' '
    if (len(bins_input)%8!=0):
        formatted_bins += bins_input[octet_num*8:]
    return formatted_bins

def format_bins_to_hex(bins_input, msb_first=True, nol=16):
    """
    返回格式化的位串，每8位插入一个空格
    """
    assert len(bins_input)%8==0, 'No alignment to octet'
    return format_bytes(bins2bytes(bins_input, msb_first=msb_first), nol=nol)
