

# Leftmost be shall be transmitted first in time
barker = '10110111000'  # data_bit^barker

# The byte on the left should be processed first, and the MSB in fields should be processed first.
def scrambler(bins_input, init_state=0x00, debug=False):
    regs = (init_state<<1) # MSB to LSB repre -7 to -1
    poly = 0x91   #10010001
    bins_out = ''
    for i in range(len(bins_input)):
        if bins_input[i]=='0':
            regs &= 0xfe
        elif bins_input[i]=='1':
            regs |= 0x01
        else:
            raise ValueError('0 or 1 expected but {} is given'.format(bins_input[i]))
        b_out = ((regs>>7)^(regs>>4)^regs)&0x01
        regs &= 0xfe
        regs |= b_out
        # dbg_info(bins_input[i], bin(regs)[2:].zfill(8))
        regs <<= 1
        # regs &= 0xff
        bins_out += str(b_out)
        if debug:
            print('{:08b}'.format(regs&0xff))
    return bins_out

def descrambler(bins_input, init_state=0x00):
    regs = (init_state<<1) # MSB to LSB repre -7 to -1
    poly = 0x91   #10010001
    bins_out = ''
    for i in range(len(bins_input)):
        if bins_input[i]=='0':
            regs &= 0xfe
        elif bins_input[i]=='1':
            regs |= 0x01
        else:
            raise ValueError('0 or 1 expected but {} is given'.format(bins_input[i]))
        b_out = ((regs>>7)^(regs>>4)^regs)&0x01
        # dbg_info(bins_input[i], bin(regs)[2:].zfill(8))
        regs <<= 1
        # regs &= 0xff
        bins_out += str(b_out)        
    return bins_out

def dbpsk_encoder(bins_input, init_state=0):
    assert init_state==0 or init_state==1
    x=str(init_state)
    bins_out = ''
    for b in bins_input:
        if b == '1':
            x = '1' if x=='0' else '0'
        bins_out += x
    return bins_out 

def dbpsk_decoder(bins_input, init_state=0):
    assert init_state==0 or init_state==1
    return ''.join(map(lambda str1,str2: '0' if str1==str2 else '1', list(bins_input), list(str(init_state)+bins_input)[:-1]))   

