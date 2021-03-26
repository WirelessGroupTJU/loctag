OBJS = csi_fun.o loctag_csi.o
CC = gcc

all: loctag_csi loctag_inject

loctag_csi: $(OBJS)
	$(CC) $(OBJS) -o loctag_csi

loctag_inject: loctag_inject.c
	$(CC) -lrt -o loctag_inject loctag_inject.c

csi_fun.o: csi_fun.c csi_fun.h
	$(CC) -c csi_fun.c -o csi_fun.o
loctag_csi.o: loctag_csi.c csi_fun.h
	$(CC) -c loctag_csi.c -o loctag_csi.o
clean: 
	rm -f *.o loctag_csi loctag_inject
