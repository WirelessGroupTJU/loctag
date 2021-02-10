`timescale 1ns/1ns
module loctag (
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
  
  ///////////////// 参数定义 /////////////  
  // MAC协议参数
  localparam Q = 2;

  // 定时参数
  localparam TRIG_RISE_TIME = 0;  // uint: 20ns
  // 探测包

  // 11b
  localparam T_B_INFO_GOT = 3;
  localparam T_B_MOD_START = 141;
  localparam T_B_CRC_START = 320;
  localparam T_B_CRC_END = 32;
  // 11n
  localparam T_N_INFO_GOT = 2;
  localparam T_N_MOD_START = 64;
  localparam T_N_MOD_END = 128;

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
  localparam N_MOD_START = 20;
  localparam N_WAIT_END = 21;

  /////////////// 变量与信号定义 ////////////
  // 状态变量
  reg [4:0] state = IDLE;
  // 由trig和定时驱动状态的转移 
  reg [5:0] divide_counter = 0;
  reg [26:0] us_counter = 0;
  
  reg counter_rst = 0;
  reg next_us = 0;

  always @(posedge clk) begin
    if (reset) begin
      divide_counter <= 0;
      us_counter <= 0;
      next_us <= 0;
    end else if (counter_rst) begin
      divide_counter <= 2;
      us_counter <= 0;
      next_us <= 0;
    end else if (divide_counter == 49) begin
      divide_counter <= 0;
      us_counter <= us_counter + 1;
      next_us <= 1;
    end else begin
      divide_counter <= divide_counter + 1;
      us_counter <= us_counter;
      next_us <= 0;
    end 
  end
  
  always @(posedge clk) begin
    if (force_fs) begin
      state <= FORCE_FS;
      counter_rst <= 1;
    end else if (~trig) begin
      state <= IDLE;
      counter_rst <= 1;
    end else begin
      case (state)

        IDLE : begin
          case (mode)
            2'b10: begin
              state <= B_START;
            end
            2'b01: begin
              state <= N_START;
            end
            // 2'b11: begin
            //   state <= P_START;
            // end
            default: begin
              state <= IDLE;
            end
          endcase
          counter_rst <= 1;
        end

        B_START : begin
          if (us_counter == T_B_INFO_GOT) begin
            state <= B_INFO_GOT;
            counter_rst <= 1;
          end else begin
            state <= B_START;
            counter_rst <= 0;
          end
        end

        B_INFO_GOT : begin
          if (us_counter == T_B_MOD_START) begin
            state <= B_MOD_START;
            counter_rst <= 1;
          end else begin
            state <= B_INFO_GOT;
            counter_rst <= 0;
          end
        end
        
        B_MOD_START : begin
          if (us_counter == T_B_CRC_START) begin
            state <= B_CRC_START;
            counter_rst <= 1;
          end else begin
            state <= B_MOD_START;
            counter_rst <= 0;
          end
        end
        
        B_CRC_START : begin
          if (us_counter == T_B_CRC_END) begin
            if (trig)
              state <= B_WAIT_END;
            else
              state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= B_CRC_START;
            counter_rst <= 0;
          end
        end

        B_WAIT_END : begin
          if (~trig) begin
            state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= B_WAIT_END;
            counter_rst <= 0;
          end
        end

        N_START : begin
          if (us_counter == T_N_INFO_GOT) begin
            state <= N_INFO_GOT;
            counter_rst <= 1;
          end else begin
            state <= N_START;
            counter_rst <= 0;
          end
        end

        N_INFO_GOT : begin
          if (us_counter == T_N_MOD_START) begin
            state <= N_MOD_START;
            counter_rst <= 1;
          end else begin
            state <= N_INFO_GOT;
            counter_rst <= 0;
          end
        end
        
        N_MOD_START : begin
          if (us_counter == T_N_MOD_END) begin
            if (trig)
              state <= N_WAIT_END;
            else
              state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= N_MOD_START;
            counter_rst <= 0;
          end
        end

        N_WAIT_END : begin
          if (~trig) begin
            state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= N_WAIT_END;
            counter_rst <= 1;
          end
        end
        
        default: begin
          state <= IDLE;
          counter_rst <= 1;
        end

      endcase
    end // if-else-end  
  end

  // ADC: B_START, N_START
  reg  adc_soc = 0;
  wire adc_eoc;
  wire [7:0] adc_data;
  reg  [7:0] rss = 8'hff;

  // 反射调制
  reg  fs_en = 0;
  reg  mod_invert = 0;
  assign ctrl_1 = (clk & fs_en) ^ mod_invert;
  
  reg  b_mod_start = 0;
  reg  b_crc_compute = 0;
  wire b_mod_out;

  // ROM Access
  localparam ADDR_WIDTH = 6;
  localparam ROM_SIZE = (2<<ADDR_WIDTH);
  reg  [7:0] ep_rom[0:ROM_SIZE-1];

  reg  [ADDR_WIDTH-1:0] rom_addr = 0;
  reg  [0:2] bit_addr = 0;
  wire [7:0] rom_data = ep_rom[rom_addr];
  wire s_data = rom_data[bit_addr];

  // 调制数据  
  wire [31:0] fcs_for_xor;
  reg  [31:0] b_fcs_data = 0;

  localparam N_LEN = 8;
  reg [N_LEN-1:0] n_data;
  wire n_s_dat = n_data[N_LEN-1];
  
  always @(posedge clk) begin
    case (state)
      B_START : begin
        fs_en <= 1;
        data <= 0;
        b_mod_start <= 0;
        b_crc_compute <= 0;
        adc_soc <= 1;
        rss <= 8'hff;
      end

      B_INFO_GOT : begin
        fs_en <= 1;
        data <= 0;
        b_mod_start <= 0;
        b_crc_compute <= 0;
        adc_soc <= 0;
        if (adc_eoc)
          rss <= adc_data;
        else
          rss <= rss;
      end

      B_MOD_START : begin
        fs_en <= 1;
        mod_invert <= b_mod_out;
        b_mod_start <= 1;
        b_crc_compute <= 1;
        adc_soc <= 0;
        rss <= rss;
        if (next_us && p2s_counter == 7) begin
          p2s_counter <= 0;
          data <= rom_data;
          rom_addr <= rom_addr+1;
          
          data[B_LEN-1:0] <= {data[B_LEN-2:0], 1'b0};
          p2s_counter <= p2s_counter+1;
        end else if (next_us) begin
            p2s_counter <= 0;
            data <= rom_data;
            rom_addr <= rom_addr+1;
          end else begin
            p2s_counter <= 0;
            data <= rom_data;
            rom_addr <= rom_addr;
          end
        else
          data <= data;
          p2s_counter <= p2s_counter;
      end

      B_CRC_START : begin
        fs_en <= 1;
        mod_invert <= b_mod_out;
        b_mod_start <= 1;
        b_crc_compute <= 0;
        b_fcs_data <= fcs_for_xor;
        adc_soc <= 0;
        rss <= rss;
      end

      B_WAIT_END : begin
        fs_en <= 1;
        mod_invert <= b_mod_out;
        b_mod_start <= 1;
        b_crc_compute <= 0;
        adc_soc <= 0;
        rss <= rss;
      end
      

      default: begin
        fs_en <= 1;
        mod_invert <= 0;
        b_mod_start <= 0;
        b_crc_compute <= 0;
        adc_soc <= 0;
        rss <= 8'hff;
      end

    endcase
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
    .clk(next_us),
    .enable(b_mod_start),
    .s_in(b_s_dat),
    .s_out(b_mod_out)
  );

  fcs_for_xor fcs_for_xor_inst (
    .clk(next_us),
    .enable(b_crc_compute),
    .s_in(b_s_dat),
    .fcs_for_xor(fcs_for_xor),
  );

  assign led  = trig;



  initial begin
    // tx_data ^ expected_data
    ep_rom[6'd00] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd01] <= 8'h00;  // 00 ^ 00
    // SSID Ext
    ep_rom[6'd02] <= 8'h00;  // 00 ^ 00
    // SSID len
    ep_rom[6'd03] <= 8'h00;  // 10 ^ 10
    // SSID 
    ep_rom[6'd04] <= 8'h7c;  // 30 ^ 4c
    ep_rom[6'd05] <= 8'h7f;  // 30 ^ 4f
    ep_rom[6'd06] <= 8'h73;  // 30 ^ 43
    ep_rom[6'd07] <= 8'h64;  // 30 ^ 54
    ep_rom[6'd08] <= 8'h71;  // 30 ^ 41
    ep_rom[6'd09] <= 8'h77;  // 30 ^ 47
    ep_rom[6'd10] <= 8'h00;  // 2d ^ 2d
    ep_rom[6'd11] <= 8'h00;  // 30 ^ 30
    ep_rom[6'd12] <= 8'h03;  // 30 ^ 33
    ep_rom[6'd13] <= 8'h01;  // 30 ^ 31
    ep_rom[6'd14] <= 8'h02;  // 30 ^ 32
    ep_rom[6'd15] <= 8'h00;  // 2d ^ 2d
    ep_rom[6'd16] <= 8'h00;  // 30 ^ 30
    ep_rom[6'd17] <= 8'h00;  // 30 ^ 30
    ep_rom[6'd18] <= 8'h00;  // 30 ^ 30
    ep_rom[6'd19] <= 8'h01;  // 30 ^ 31
    // Vendor Spec info
    ep_rom[6'd20] <= 8'h00;  // dd ^ dd
    ep_rom[6'd21] <= 8'h00;  // 0c ^ 0c
    ep_rom[6'd22] <= 8'h00;  // 54 ^ 54
    ep_rom[6'd23] <= 8'h00;  // 4a ^ 4a
    ep_rom[6'd24] <= 8'h00;  // 55 ^ 55
    ep_rom[6'd25] <= 8'h00;  // 00 ^ 00
    // payload 2
    ep_rom[6'd26] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd27] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd28] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd29] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd30] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd31] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd32] <= 8'h00;  // 00 ^ 00
    ep_rom[6'd33] <= 8'h00;  // 00 ^ 00
    // crc32 placehold
    ep_rom[6'd34] <= 8'h00;
    ep_rom[6'd35] <= 8'h00;
    ep_rom[6'd36] <= 8'h00;
    ep_rom[6'd37] <= 8'h00;

  end

endmodule
