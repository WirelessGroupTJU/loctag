`timescale 1ns/1ns
module loctag # (
    parameter TAG_ID = "LOCTAG-0312-0001",
    parameter [15:0] MAC_SEED = 16'h4C06,
    parameter MAC_Q = 0,
    parameter N_SUBFRAME_NUM = 64,
    parameter [0:63] N_BIT_DATA = 64'h312001_00_00000000,
    parameter SGI = 0
  )
  (
  // 50MHz clock input
  input  clk,
  input  reset,
  output lt5534_en,
  output adc_cs,
  output adc_clk,
  input  adc_so,
  input  trig,

  output ctrl_1,

  input  force_fs,
  input  [1:0] mode,
  output led
  );

  ///////////////// 端口设置 /////////////
  assign lt5534_en = 1'b1;
  assign led  = trig | force_fs;
  
  ///////////////// 参数定义 /////////////  

  // 定时参数
  localparam TRIG_DELAY_COMPENSATION_US = 2;  // 提前多少us开始调制过程，以补偿TRIG检测延迟
  localparam TRIG_DELAY_COMPENSATION_20NS = 25;  // 在us级补偿的基础上延迟多少个20ns开始调制，取值范围为1到48
  // 
  // 探测包

  // 11b, 1Mbps
  // PLCP header 144+48, before_mod: 34*8=272, mod: 34*8=272, crc: 32.
  // summary: 464+272+32= 736+32
  localparam T_B_INFO_GOT = 3;
  localparam T_B_MOD_START = 461-TRIG_DELAY_COMPENSATION_US; // 检测延迟
  localparam T_B_CRC_START = 272;
  localparam T_B_CRC_END = 32;
  // 11n. see TableIEEE Std 802.11-2016, Figure 19-4
  localparam T_N_INFO_GOT = 3;
  localparam T_N_MOD_START = 64;
  localparam T_N_SUBFRAME_LEN = 12;

  ///////////////// 状态定义 ///////////////
  localparam IDLE = 0;
  localparam FORCE_FS = 1;  
  // 请求包，2~9

  // 11b, 10~17
  localparam B_START = 10;
  localparam B_INFO_GOT = 11;  // 已获得RSS和MAC协议运行结果
  localparam B_MOD_START = 12;
  localparam B_CRC_START = 13;
  localparam B_WAIT_END = 14; // TRIG仍然为高，等待
  // 11n, 18~25
  localparam N_START = 18;
  localparam N_INFO_GOT = 19;
  localparam N_MOD_LOOP = 20;
  localparam N_WAIT_END = 21;

  //////////////////// 计时器 /////////////////////
  reg [5:0] b_divide_counter = 0;
  reg [15:0] b_symbol_counter = 0;  // 65ms
  
  reg  b_counter_rst = 0;
  wire b_next_symbol = b_divide_counter == 49? 1: 0;
  wire b_next_symbol_3 = b_divide_counter == 3? 1: 0;
  wire b_next_symbol_5 = b_divide_counter == 5? 1: 0;

  always @(posedge clk) begin
    if (reset) begin
      b_divide_counter <= 0;
      b_symbol_counter <= 0;
    end else if (b_counter_rst) begin
      b_divide_counter <= 2;
      b_symbol_counter <= 0;
    end else if (b_divide_counter == 49) begin
      b_divide_counter <= 0;
      b_symbol_counter <= b_symbol_counter + 1;
    end else begin
      b_divide_counter <= b_divide_counter + 1;
      b_symbol_counter <= b_symbol_counter;
    end
  end
  // symbol in 802.11n is 3.6us(SGI) or 4.0us(LGI)
  // see IEEE Std 802.11-2016, Table 19-6
  localparam SYMBOL_PERIOD_IN_20NS = SGI? 200 : 180;
  reg  n_counter_rst = 0;
  reg  [8:0] n_divide_counter = 0;
  reg  [19:0] n_symbol_counter = 0;
  
  always @(posedge clk) begin
    if (reset) begin
      n_divide_counter <= 0;
      n_symbol_counter <= 0;
    end else if (n_counter_rst) begin
      n_divide_counter <= 2;
      n_symbol_counter <= 0;
    end else if (n_divide_counter == SYMBOL_PERIOD_IN_20NS-1) begin
      n_divide_counter <= 0;
      n_symbol_counter <= n_symbol_counter + 1;
    end else begin
      n_divide_counter <= n_divide_counter + 1;
      n_symbol_counter <= n_symbol_counter;
    end 
  end

  ////////////////////// 状态机 /////////////////
  // 状态变量
  reg [4:0] state = IDLE;
  // 状态信号
  wire adc_eoc; // ADC转换完成
  wire mac_out;
  // 控制信号
  reg  fs_en = 0;
  reg  adc_soc = 0;
  // 11b
  reg  b_crc_compute = 0;
  reg  b_mod_start = 0;
  reg  b_rom_out_enable = 0;
  reg  b_crc32_out_enable = 0;
  wire b_mod_out;
  reg  b_mod_invert = 0;
  wire b_mod_invert_tmp = b_mod_start & b_mod_out; 
  always @(posedge b_next_symbol_5) begin
    b_mod_invert <= b_mod_invert_tmp; // 防止毛刺
  end
  // 11n
  reg  n_mod_invert = 0;
  
  // 反射开关控制信号 
  wire mod_invert = b_mod_invert | n_mod_invert;
  assign ctrl_1 = (clk & fs_en) ^ mod_invert;  
  
  ////////// 数据 /////////
  // adc
  wire [7:0] adc_data;
  // 11b ROM Access
  localparam ADDR_WIDTH = 6;
  localparam ROM_SIZE = 2**ADDR_WIDTH;
  reg  [ADDR_WIDTH-1:0] b_rom_addr = 0;
  reg  [0:2] b_bit_addr = 0;
  // 11b ROM
  reg  [7:0] b_rom[0:ROM_SIZE-1];
  wire [7:0] b_rom_data = b_rom[b_rom_addr];
 
  // 11b fcs
  wire [31:0] b_fcs_for_xor;
  reg  [31:0] b_fcs_data = 0;

  // 11b 输入到调制器的串行数据
  wire b_s_data = (b_rom_out_enable & b_rom_data[b_bit_addr])
                  | (b_crc32_out_enable & b_fcs_data[31]);
  // 11n
  reg  n_demage = 0;
  reg  [5:0] n_bit_addr = 0;
  reg  [0:63] n_bit_rom = N_BIT_DATA[0:63];

  // 状态机
  always @(posedge clk) begin
    if (force_fs) begin
      state <= FORCE_FS;
      fs_en <= 1;
      adc_soc <= 0;

      b_counter_rst <= 1;
      b_crc_compute <= 0;
      b_mod_start <= 0;
      b_rom_out_enable <= 0;
      b_crc32_out_enable <= 0;
      b_rom_addr <= 6'd00;
      b_bit_addr <= 0;

      n_counter_rst <= 1;
      n_demage <= 0;
      n_bit_addr <= 0;
      
    end else if (~trig) begin
      state <= IDLE;
      fs_en <= 0;
      adc_soc <= 0;

      b_counter_rst <= 1;
      b_crc_compute <= 0;
      b_mod_start <= 0;
      b_rom_out_enable <= 0;
      b_crc32_out_enable <= 0;
      b_rom_addr <= 6'd00;
      b_bit_addr <= 0;

      n_counter_rst <= 1;
      n_demage <= 0;
      n_bit_addr <= 0;

    end else begin
      case (state)
        IDLE : begin
          case (mode)
            2'b10: begin
              if (mac_out)
                state <= B_START;
              else
                state <= B_WAIT_END;
            end
            2'b01: begin
              if (mac_out)
                state <= N_START;
              else
                state <= N_WAIT_END;
            end
            // 2'b11: begin
            //   state <= P_START;
            // end
            default: begin
              state <= IDLE;
            end
          endcase
          fs_en <= 0;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;
        end

        B_START : begin
          if (b_symbol_counter == T_B_INFO_GOT) begin
            state <= B_INFO_GOT;
            b_counter_rst <= 1;
          end else begin
            state <= B_START;
            b_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 1;

          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd26;
          b_bit_addr <= 0;

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;

          if (adc_eoc)
            b_rom[b_rom_addr] <= adc_data;
          else
            b_rom[b_rom_addr] <= b_rom[b_rom_addr];
        end

        B_INFO_GOT : begin
          if (b_symbol_counter == T_B_MOD_START && b_divide_counter==TRIG_DELAY_COMPENSATION_20NS) begin
            state <= B_MOD_START;
            b_counter_rst <= 1;
          end else begin
            state <= B_INFO_GOT;
            b_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;

          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;
        end
        
        B_MOD_START : begin
          if (b_symbol_counter == T_B_CRC_START) begin
            state <= B_CRC_START;
            b_counter_rst <= 1;
            b_fcs_data <= b_fcs_for_xor; //
          end else begin
            state <= B_MOD_START;
            b_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;

          b_crc_compute <= 1;
          b_mod_start <= 1;
          b_rom_out_enable <= 1;
          b_crc32_out_enable <= 0;
          if (b_next_symbol) begin
            b_bit_addr <= b_bit_addr+1;
            if (b_bit_addr == 7) begin
              b_rom_addr <= b_rom_addr+1;
            end else begin
              b_rom_addr <= b_rom_addr;
            end  
          end else begin
            b_bit_addr <= b_bit_addr;
            b_rom_addr <= b_rom_addr;
          end

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;          
        end
        
        B_CRC_START : begin
          if (b_symbol_counter == T_B_CRC_END) begin
            if (trig)
              state <= B_WAIT_END;
            else
              state <= IDLE;
            b_counter_rst <= 1;
          end else begin
            state <= B_CRC_START;
            b_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;

          b_crc_compute <= 0;
          b_mod_start <= 1;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 1;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;   

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;

          if (b_next_symbol) begin
            b_fcs_data[31:0] <= {b_fcs_data[30:0], 1'b0};
          end else begin
            b_fcs_data <= b_fcs_data;
          end
        end

        B_WAIT_END : begin
          if (~trig) begin
            state <= IDLE;     
          end else begin
            state <= B_WAIT_END;
          end

          fs_en <= 0;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;   

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;
        end

        N_START : begin
          if (n_symbol_counter == T_N_INFO_GOT) begin
            state <= N_INFO_GOT;
            n_counter_rst <= 1;
          end else begin
            state <= N_START;
            n_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 1;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_demage <= 0;
          n_bit_addr <= 0;

          if (adc_eoc)
            n_bit_rom[2*8+:8] <= adc_data;
          else
            n_bit_rom[2*8+:8] <= n_bit_rom[2*8+:8];
        end

        N_INFO_GOT : begin
          if (n_symbol_counter == T_N_MOD_START) begin
            state <= N_MOD_LOOP;
            n_counter_rst <= 1;
          end else begin
            state <= N_INFO_GOT;
            n_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_demage <= 0;
          n_bit_addr <= 0;
        end
        
        N_MOD_LOOP : begin
          if (n_bit_addr == N_SUBFRAME_NUM) begin
            if (trig)
              state <= N_WAIT_END;
            else
              state <= IDLE;
            n_bit_addr <= 0;
            n_counter_rst <= 1;
          end else if (n_symbol_counter == T_N_SUBFRAME_LEN && n_divide_counter[2:0]==0) begin
              state <= N_MOD_LOOP;
              n_bit_addr <= n_bit_addr+1;
              n_counter_rst <= 1;              
          end else begin
            state <= N_MOD_LOOP;
            n_bit_addr <= n_bit_addr;
            n_counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          if (n_symbol_counter == T_N_SUBFRAME_LEN/2)
            n_demage <= n_bit_rom[n_bit_addr];
          else if (n_symbol_counter == T_N_SUBFRAME_LEN/2+4)
            n_demage <= 0;
          else
            n_demage <= n_demage;
        end

        N_WAIT_END : begin
          if (~trig) begin
            state <= IDLE;
          end else begin
            state <= N_WAIT_END;
          end

          fs_en <= 0;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;
        end
        
        default: begin
          state <= IDLE;
          fs_en <= 0;
          adc_soc <= 0;

          b_counter_rst <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
          b_rom_addr <= 6'd00;
          b_bit_addr <= 0;

          n_counter_rst <= 1;
          n_demage <= 0;
          n_bit_addr <= 0;
        end

      endcase
    end // if-else-end  
  end


  reg clk_25mhz = 0;
	reg clk_12mhz = 0;
	always @(posedge clk) clk_25mhz = !clk_25mhz;
	always @(posedge clk_25mhz) clk_12mhz = !clk_12mhz;

  adc7478 adc7478_inst (
    .clk_in(clk_12mhz),
    .start(adc_soc),
    .cs(adc_cs),
    .clk(adc_clk),
    .so(adc_so),
    .eoc(adc_eoc),
    .data(adc_data)
  );

  b_modulator b_modulator_inst (
    .clk(b_next_symbol),
    .enable(b_mod_start),
    .s_in(b_s_data),
    .s_out(b_mod_out)
  );

  fcs_for_xor fcs_for_xor_inst (
    .clk(b_next_symbol_3),
    .enable(b_crc_compute),
    .s_in(b_s_data),
    .val(b_fcs_for_xor)
  );

  mac # (
    .MAC_SEED(MAC_SEED),
    .MAC_Q(MAC_Q)
  ) mac_inst
  (
    .clk(clk),
    .enable(1'b1),
    .out(mac_out)
  );

  integer i;
  parameter SSID_PADDING = "000000-0000-0000";
  initial begin
    // tag_data = tx_data ^ expected_data
  
    for (i = 0; i<4; i=i+1) begin
        b_rom[i] <= 8'h00;
    end
    // 初始化标签ID，标签ID共16字节
    for (i = 0; i<16; i=i+1) begin
        b_rom[4+16-i-1] <= SSID_PADDING[i*8+:8] ^ TAG_ID[i*8+:8];
    end
    for (i = 4+16; i<ROM_SIZE; i=i+1) begin
        b_rom[i] <= 8'h00;
    end

    n_bit_rom <= N_BIT_DATA;

  end

endmodule
