OBJS = csi_fun.o loctag.o
CC = gcc
loctag: $(OBJS)
	$(CC) $(OBJS) -o loctag
csi_fun.o: csi_fun.c csi_fun.h
	$(CC) -c csi_fun.c -o csi_fun.o
loctag.o: loctag.c csi_fun.h
	$(CC) -c loctag.c -o loctag.o
clean: 
	rm -f *.o loctag

