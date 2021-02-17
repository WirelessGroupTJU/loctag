import struct, sys, os

class DriverUtil:
    def __init__(self, dev='/dev/CSI_dev'):
        self.dfd = os.open(dev, os.O_RDWR)

    def set_filter(self, isFilter=1, addr2=b'\x00\x00\x00\x00\x00\x00'):
        data = struct.pack('BB6s', 11, isFilter, addr2)
        os.write(self.dfd, data)

    def set_txpower(self, isFixed=0, txpower=63):
        data = struct.pack('BBB', 12, isFixed, txpower)
        os.write(self.dfd, data)

    def __del__(self):
        os.close(self.dfd)

if __name__ == "__main__":

    du = DriverUtil()
    du.set_filter(isFilter=1, addr2=b'\xb4\xee\xb4\xb7\x0b\x3c')

    print('done')