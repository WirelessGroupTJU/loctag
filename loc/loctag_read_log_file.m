%%
%% =====================================================================================
%%       Filename:  read_log_file.m 
%%
%%    Description:  extract the CSI, payload, and packet status information from the log
%%                  file
%%        Version:  1.0
%%
%%         Author:  Yaxiong Xie 
%%         Email :  <xieyaxiongfly@gmail.com>
%%   Organization:  WANDS group @ Nanyang Technological University 
%%
%%   Copyright (c)  WANDS group @ Nanyang Technological University
%% =====================================================================================
%%

function ret = loctag_read_log_file(filename, optarg)
arguments % Matlab R2019b or later
    filename {mustBeFile};
    optarg.rssi_base {mustBeReal, mustBeScalarOrEmpty} = -95;
end

f = fopen(filename, 'rb');
if (f < 0)
    error('couldn''t open file %s', filename);
end

status = fseek(f, 0, 'eof');
if status ~= 0
    [msg, errno] = ferror(f);
    fclose(f);
    error('Error %d seeking: %s', errno, msg);    
end
len = ftell(f);
fprintf('file %s length is:%d\n',filename, len);

status = fseek(f, 0, 'bof');
if status ~= 0
    [msg, errno] = ferror(f);
    fclose(f);
    error('Error %d seeking: %s', errno, msg);
end

ret = cell(ceil(len / 420),1);
cur = 0;
count = 0;

endian_format = 'ieee-le'; % should be 'ieee-le' rather than 'ieee-be'

while cur < (len - 4)
    field_len = fread(f, 1, 'uint16', 0, endian_format);
	cur = cur + 2;
    printf_i('Block length is:%d\n',field_len);

	if (cur + field_len) > len
   		break;
    end
    
    timestamp = fread(f, 1, 'uint64', 0, [endian_format '.l64']);
	pkt_record.timestamp = timestamp;
	cur = cur + 8;

    csi_len = fread(f, 1, 'uint16', 0, endian_format);
% 	pkt_record.csi_len = csi_len;
	cur = cur + 2;

    tx_channel = fread(f, 1, 'uint16', 0, endian_format);
	pkt_record.channel = tx_channel;
	cur = cur + 2;
   
    err_info = fread(f, 1,'uint8=>int');
    pkt_record.err_info = err_info;
    cur = cur + 1;
    
    noise_floor = fread(f, 1, 'uint8=>int');
	pkt_record.crc_err = noise_floor;
	cur = cur + 1;
    
    rate = fread(f, 1, 'uint8=>int'); %11b 1Mbps:0x1b, 11n mcs0: 0x80;
	pkt_record.rate = rate;
	cur = cur + 1; 
    
    bandWidth = fread(f, 1, 'uint8=>int');
% 	pkt_record.bandWidth = bandWidth;
	cur = cur + 1;
    
    num_tones = fread(f, 1, 'uint8=>int');
	pkt_record.num_tones = num_tones;
	cur = cur + 1;

	nr = fread(f, 1, 'uint8=>int');
	pkt_record.nr = nr;
	cur = cur + 1;

	nc = fread(f, 1, 'uint8=>int');
	pkt_record.nc = nc;
	cur = cur + 1;
	
	rssi = fread(f, 1, 'uint8=>int') + optarg.rssi_base; % convert rssi to dbm, the same below
	pkt_record.rss = int32(rssi);
	cur = cur + 1;

	rssi1 = fread(f, 1, 'uint8=>int') + optarg.rssi_base;
	%pkt_record.rssi1 = rssi1;
	cur = cur + 1;
	%printf_i('rssi1 is %d\n',rssi1);

	rssi2 = fread(f, 1, 'uint8=>int') + optarg.rssi_base;
	%pkt_record.rssi2 = rssi2;
	cur = cur + 1;
	%printf_i('rssi2 is %d\n',rssi2);

	rssi3 = fread(f, 1, 'uint8=>int') + optarg.rssi_base;
	%pkt_record.rssi3 = rssi3;
	cur = cur + 1;
	%printf_i('rssi3 is %d\n',rssi3);
    pkt_record.ant_rss=int32([rssi1, rssi2, rssi3]);
    
    payload_len = fread(f, 1, 'uint16', 0, endian_format);
	pkt_record.payload_len = payload_len;
	cur = cur + 2;
    printf_i('payload length: %d\n',payload_len);	
    
    if csi_len > 0
        csi_buf = fread(f, csi_len, 'uint8=>uint8');
	    csi = read_csi(csi_buf, nr, nc, num_tones);
    	cur = cur + csi_len;
	    pkt_record.csi = []; %csi;
    else
        pkt_record.csi = [];
    end       
    
    if payload_len > 0
        mpdu = fread(f, payload_len, 'uint8=>uint8');	    
    	cur = cur + payload_len;
        if rate == 0x1b
            pkt_record.payload = mpdu;
            pkt_record.txMac = sprintf('%02x:%02x:%02x:%02x:%02x:%02x', mpdu(11),mpdu(12),mpdu(13),mpdu(14),mpdu(15),mpdu(16));
            id_str = char(mpdu(39:50))';
            if strncmp(id_str, 'LOCTAG-10000', 11) && any(id_str(end)==['1', '2', '3'])
                pkt_record.id = uint8(id_str(end))-uint8('0');%mpdu(38+11+1);
            else
                pkt_record.id = uint8(0);
            end
            adc = mpdu(56+1);
            if adc>80 || adc==0
                pkt_record.tag_rss = double(adc)*0.333-65.4;
            else
                pkt_record.tag_rss = double(128+bitsrl(adc, 1))*0.333-65.4;
            end
        elseif rate==0x80
            pkt_record.payload = mpdu;
            pkt_record.txMac = sprintf('%02x:%02x:%02x:%02x:%02x:%02x', mpdu(11),mpdu(12),mpdu(13),mpdu(14),mpdu(15),mpdu(16));
            pkt_record.id =  uint8(0);
            pkt_record.tag_rss = double(0);
        else
            pkt_record = []; %清空当前记录
            fprintf('W: rate 0x%02x unused in packet %d\n', rate, count);
            continue
        end
    else
        pkt_record = []; %清空当前记录
        fprintf('W: payload_len < 0 in packet %d\n', count);
        continue
    end
    
    if (cur + 420 > len)
        break;
    end
    count = count + 1;
    ret{count} = pkt_record;
end
if (count >1)
	ret = ret(1:(count-1));
else
	ret = ret(1);
end
fclose(f);
end
