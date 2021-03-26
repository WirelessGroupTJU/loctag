//
// Created by shwei on 2021/03/26.
//
// #define _POSIX_C_SOURCE 199309L
#include <linux/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <errno.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <linux/if_ether.h>
#include <net/if.h>
#include <netpacket/packet.h>

#define MAX_FRAME_SIZE 4096

const char *ifname = "wlan0";

const uint8_t loctag_b_pkt[MAX_FRAME_SIZE] = "\x00\x00\x0D\x00\x04\x80\x02\x00\x02\x00\x00\x00\x00" \
        "\x80\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xB4\xEE\xB4\xB7\x0B\x3C" \
        "\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" \
        "\x64\x00\x00\x00\x00\x0C\x30\x30\x30\x30\x30\x30\x2D\x30\x30\x30" \
        "\x30\x30\xDD\x0C\x54\x4A\x55\x00\x00\x00\x00\x00\x00\x00\x00\x00";
const int32_t loctag_b_pkt_size = 77;
const uint8_t loctag_n_pkt[MAX_FRAME_SIZE] = "\x00\x00\x0E\x00\x00\x80\x0A\x00\x00\x00\x00\x07\x00\x00" \
        "\x08\x00\x00\x00\xB4\xEE\xB4\xB7\x08\xF4\xB4\xEE\xB4\xB7\x0B\x3C" \
        "\xB4\xEE\xB4\xB7\x0B\x3C\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" \
        "\x00\x00\x00\x00";
const int32_t loctag_n_pkt_size = 50;

int32_t create_raw_socket(const char* p_iface);

int32_t main(int argc, char *argv[])
{   
    int32_t t_socket;
    uint32_t num_packets;
    uint32_t i;
    uint32_t mode;
    uint32_t delay_us;
	struct timespec start, now;
	int32_t diff;
    int32_t t_size;

    /* Parse arguments */
	if (argc > 4) {
		printf("Usage: random_packets <number> <mode: 0=11b, 1=11n, 2=11b+11n> <delay in us>\n");
		return 1;
	}
	if (argc < 4 || (1 != sscanf(argv[3], "%u", &delay_us))) {
		delay_us = 0;
	}
	if (argc < 3 || (1 != sscanf(argv[2], "%u", &mode))) {
		mode = 2;
		printf("Usage: random_packets <number> <mode: 0=11b, 1=11n, 2=11b+11n> <delay in us>\n");
	} else if (mode > 2) {
		printf("Usage: random_packets <number> <mode: 0=11b, 1=11n, 2=11b+11n> <delay in us>\n");
		return 1;
	}
	if (argc < 2 || (1 != sscanf(argv[1], "%u", &num_packets)))
		num_packets = 2000;

    t_socket = create_raw_socket(ifname);

    if (delay_us) {
		/* Get start time */
		clock_gettime(CLOCK_MONOTONIC, &start);
	}
    for (i = 0; i < num_packets; ++i) {
		if (delay_us) {
			clock_gettime(CLOCK_MONOTONIC, &now);
			diff = (now.tv_sec - start.tv_sec) * 1000000 +
			       (now.tv_nsec - start.tv_nsec + 500) / 1000;
			diff = delay_us*i - diff;
			if (diff > 0 && diff < delay_us)
				usleep(diff);
		}
        if (mode==0 || mode==2) {
            t_size = write(t_socket, loctag_b_pkt, loctag_b_pkt_size);
            if(t_size<0) {
                perror("<main> write(b) failed!");
                exit(1);
            }
        }
        if (mode==1 || mode==2) {
            t_size = write(t_socket, loctag_n_pkt, loctag_n_pkt_size);
            if(t_size<0) {
                perror("<main> write(n) failed!");
                exit(1);
            }
        }

		if (((i+1) % 1000) == 0) {
			printf(".");
			fflush(stdout);
		}
		if (((i+1) % 50000) == 0) {
			printf("%dk\n", (i+1)/1000);
			fflush(stdout);
		}
	}

    return 0;
}


int32_t create_raw_socket(const char* p_iface)
{
    /* new raw socket */
    int32_t t_socket=socket(PF_PACKET,SOCK_RAW,htons(ETH_P_ALL));
    if(t_socket<0)
    {
        perror("<create_raw_socket> socket(PF_PACKET,SOCK_RAW,htons(ETH_P_ALL)) failed!");
        return -1;
    }
    /* get the index of the interface */
    struct ifreq t_ifr;
    memset(&t_ifr,0,sizeof(t_ifr));
    strncpy(t_ifr.ifr_name,p_iface,sizeof(t_ifr.ifr_name)-1);
    if(ioctl(t_socket,SIOCGIFINDEX,&t_ifr)<0)
    {
        perror("<create_raw_socket> ioctl(SIOCGIFINDEX) failed!");
        return -1;
    }
    /* bind the raw socket to the interface */
    struct sockaddr_ll t_sll;
    memset(&t_sll,0,sizeof(t_sll));
    t_sll.sll_family=AF_PACKET;
    t_sll.sll_ifindex=t_ifr.ifr_ifindex;
    t_sll.sll_protocol=htons(ETH_P_ALL);
    if(bind(t_socket,(struct sockaddr*)&t_sll,sizeof(t_sll))<0)
    {
        perror("<create_raw_socket> bind(ETH_P_ALL) failed!");
        return -1;
    }
    /* open promisc */
    struct packet_mreq t_mr;
    memset(&t_mr,0,sizeof(t_mr));
    t_mr.mr_ifindex=t_sll.sll_ifindex;
    t_mr.mr_type=PACKET_MR_PROMISC;
    if(setsockopt(t_socket,SOL_PACKET,PACKET_ADD_MEMBERSHIP,&t_mr,sizeof(t_mr))<0)
    {
        perror("<create_raw_socket> setsockopt(PACKET_MR_PROMISC) failed!");
        return -1;
    }
    return t_socket;
}