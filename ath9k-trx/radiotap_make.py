import radiotap

rate_bga_value = {
    1: 0x02,
    2: 0x04,
    5.5: 0x0b,
    11: 0x16,
    6: 0x0c,
    9: 0x12,
    12: 0x18,
    18: 0x24,
    24: 0x30,
    36: 0x48,
    48: 0x60,
    54: 0x6c,
}

RADIOTAP_FIELD_TABLE = [
    'TSFT',
    'FLAGS',
    'RATE',
    'CHANNEL',
    'FHSS',
    'DBM_ANTSIGNAL',
    'DBM_ANTNOISE',
    'LOCK_QUALITY',
    'TX_ATTENUATION',
    'DB_TX_ATTENUATION',
    'DBM_TX_POWER',
    'ANTENNA',
    'DB_ANTSIGNAL',
    'DB_ANTNOISE',
    'RX_FLAGS',
    'TX_FLAGS',
    'RTS_RETRIES',
    'DATA_RETRIES',
    'XChannel',
    'MCS',
    'AMPDU_STATUS',
    'VHT',
    'TIMESTAMP',
    'n',
    'n',
    'n',
    'n',
    'n',
    'n',
    'RADIOTAP_NAMESPACE',
    'VENDOR_NAMESPACE',
    'EXT'
]

def parse_radiotap_index(present_bytes):
    present_bits = '{:032b}'.format(int.from_bytes(present_bytes, byteorder='little'))[::-1]
    field_list = []
    for i,b in enumerate(present_bits):
        if b=='1':
            field_list.append((i, RADIOTAP_FIELD_TABLE[i]))
    return field_list

radiotap_bga = (b'\x00\x00' b'\x0d\x00' b'\x04\x80\x02\x00' b'\x02' b'\x00\x00\x00' b'\x00')
radiotap_ht  = (b'\x00\x00' b'\x0e\x00' b'\x00\x80\x0a\x00' b'\x00\x00' b'\x00' b'\x07\x00\x01')

r_hdr_len, r_hdr_parsed = radiotap.radiotap_parse(radiotap_ht)
print(parse_radiotap_index(b'\x00\x80\x0a\x00'))
print(r_hdr_len, r_hdr_parsed)

