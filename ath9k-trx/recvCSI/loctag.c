/*
 * =====================================================================================
 *       Filename:  main.c
 *
 *    Description:  Here is an example for receiving CSI matrix 
 *                  Basic CSi procesing fucntion is also implemented and called
 *                  Check csi_fun.c for detail of the processing function
 *        Version:  1.0
 *
 *         Author:  Yaxiong Xie
 *         Email :  <xieyaxiongfly@gmail.com>
 *   Organization:  WANDS group @ Nanyang Technological University
 *   
 *   Copyright (c)  WANDS group @ Nanyang Technological University
 * =====================================================================================
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <pthread.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "csi_fun.h"

#define BUFSIZE 4096

int quit;
unsigned char buf_addr[BUFSIZE];
unsigned char data_buf[1500];
unsigned char *mpdu;

COMPLEX csi_matrix[3][3][114];
csi_struct*   csi_status;

void sig_handler(int signo)
{
    if (signo == SIGINT)
        quit = 1;
}

int main(int argc, char* argv[])
{
    FILE*       fp;
    int         fd;
    int         i;
    int         total_msg_cnt,cnt;
    int         log_flag;
    unsigned char endian_flag;
    u_int16_t   buf_len;

    int rssi, rssi_0, rssi_1, rssi_2;
    float  tag_rss;
    
    log_flag = 1;
    csi_status = (csi_struct*)malloc(sizeof(csi_struct));
    /* check usage */
    if (1 == argc){
        /* If you want to log the CSI for off-line processing,
         * you need to specify the name of the output file
         */
        log_flag  = 0;
        printf("/**************************************/\n");
        printf("/*   Usage: recv_csi <output_file>    */\n");
        printf("/**************************************/\n");
    }
    if (2 == argc){
        fp = fopen(argv[1],"w");
        if (!fp){
            printf("Fail to open <output_file>, are you root?\n");
            fclose(fp);
            return 0;
        }   
    }
    if (argc > 2){
        printf(" Too many input arguments !\n");
        return 0;
    }

    fd = open_csi_device();
    if (fd < 0){
        perror("Failed to open the device...");
        return errno;
    }
    
    printf("#Receiving data! Press Ctrl+C to quit!\n");

    quit = 0;
    total_msg_cnt = 0;
    
    write(fd, "\x0b\x01\xb4\xee\xb4\xb7\x0b\x3c", 8);

    while(1){
        if (1 == quit){
            return 0;
            fclose(fp);
            close_csi_device(fd);
        }

        /* keep listening to the kernel and waiting for the csi report */
        cnt = read_csi_buf(buf_addr,fd,BUFSIZE);

        if (cnt){
            total_msg_cnt += 1;

            /* fill the status struct with information about the rx packet */
            record_status(buf_addr, cnt, csi_status);
            mpdu = buf_addr + 23 + csi_status->csi_len + 2;
            /* 
             * fill the payload buffer with the payload
             * fill the CSI matrix with the extracted CSI value
             */
            // record_csi_payload(buf_addr, csi_status, data_buf, csi_matrix); 
            
            /* Till now, we store the packet status in the struct csi_status 
             * store the packet payload in the data buffer
             * store the csi matrix in the csi buffer
             * with all those data, we can build our own processing function! 
             */
            // porcess_csi(data_buf, csi_status, csi_matrix);   
            rssi = csi_status->rssi - 95;
            rssi_0 = csi_status->rssi_0 - 95;
            rssi_1 = csi_status->rssi_1 - 95;
            rssi_2 = csi_status->rssi_2 - 95;

            if (csi_status->rate > 0x80) {
                printf("%04d rate: 0x%02x, rssi: %d(%d|%d|%d), len: %d  csi: %dx%dx%d\n", \
                    total_msg_cnt, csi_status->rate, rssi, rssi_0, rssi_1, rssi_2, \
                    csi_status->payload_len, \
                    csi_status->nr, csi_status->nc, csi_status->num_tones );
            } else if (csi_status->rate == 0x1b) { //11b
                if (mpdu[0] == 0x80) { //beacon
                    tag_rss = (unsigned int)mpdu[60]*0.333 - 65.4;
                    printf("%04d rate: 0x%02x, rssi: %d(%d|%d|%d), len: %d  tag_rss: %5.1f %.*s\n", \
                        total_msg_cnt, csi_status->rate, rssi, rssi_0, rssi_1, rssi_2, \
                        csi_status->payload_len, \
                        tag_rss, mpdu[37], &mpdu[38] );
                }
            } else {
                printf("%04d rate: 0x%02x, rssi: %d(%d|%d|%d), len: %d\n", \
                    total_msg_cnt, csi_status->rate, rssi, rssi_0, rssi_1, rssi_2, \
                    csi_status->payload_len \
                    );
            }
            /* log the received data for off-line processing */
            if (log_flag){
                buf_len = csi_status->buf_len;
                fwrite(&buf_len,1,2,fp);
                fwrite(buf_addr,1,buf_len,fp);
            }
        }
    }
    fclose(fp);
    close_csi_device(fd);
    free(csi_status);
    return 0;
}
