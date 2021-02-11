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
  assign led  = trig;
  
  ///////////////// 参数定义 /////////////  
  // MAC协议参数
  localparam Q = 2;

  // 定时参数
  localparam TRIG_RISE_TIME = 1;  // uint: 20ns
  // 探测包

  // 11b, 1Mbps
  // PLCP header 144+48, before_mod: 34*8=272, mod: 34*8=272, crc: 32.
  // summary: 464+272+32= 736+32
  localparam T_B_INFO_GOT = 3;
  localparam T_B_MOD_START = 462; // 检测延迟
  localparam T_B_CRC_START = 272;
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

  //////////////////// 计时器 /////////////////////
  reg [5:0] divide_counter = 0;
  reg [26:0] us_counter = 0;
  
  reg counter_rst = 0;
  wire next_us = divide_counter == 49? 1: 0;
  wire next_us_0 = divide_counter == 0? 1: 0;
  wire next_us_3 = divide_counter == 3? 1: 0;
  wire next_us_9 = divide_counter == 40? 1: 0;

  always @(posedge clk) begin
    if (reset) begin
      divide_counter <= 0;
      us_counter <= 0;
    end else if (counter_rst) begin
      divide_counter <= 2;
      us_counter <= 0;
    end else if (divide_counter == 49) begin
      divide_counter <= 0;
      us_counter <= us_counter + 1;
    end else begin
      divide_counter <= divide_counter + 1;
      us_counter <= us_counter;
    end 
  end


  ////////////////////// 状态机 /////////////////
  // 状态变量
  reg [4:0] state = IDLE;
  // 状态信号
  wire adc_eoc; // ADC转换完成
  // 控制信号
  reg  fs_en = 0;
  reg  adc_soc = 0;
  reg  b_crc_compute = 0;
  reg  b_mod_start = 0;
  reg  b_rom_out_enable = 0;
  reg  b_crc32_out_enable = 0;
  // 反射开关控制信号
  wire b_mod_out;
  reg  mod_invert = 0;
  wire mod_invert_tmp = b_mod_start & b_mod_out; 
  assign ctrl_1 = (clk & fs_en) ^ mod_invert; 
  always @(posedge next_us_9) begin
    mod_invert <= mod_invert_tmp; // 防止毛刺
  end
  // adc
  wire [7:0] adc_data;
  // common ROM Access
  localparam ADDR_WIDTH = 6;
  localparam ROM_SIZE = (2<<ADDR_WIDTH);
  reg  [ADDR_WIDTH-1:0] rom_addr = 0;
  reg  [0:2] bit_addr = 0;
  // 11b ROM
  reg  [7:0] b_rom[0:ROM_SIZE-1];
  wire [7:0] b_rom_data = b_rom[rom_addr];
 
  // 11b fcs
  wire [31:0] b_fcs_for_xor;
  reg  [31:0] b_fcs_data = 0;

  // 11b 输入到调制器的串行数据
  wire b_s_data = (b_rom_out_enable & b_rom_data[bit_addr])
                  | (b_crc32_out_enable & b_fcs_data[31]);

  // 状态机
  always @(posedge clk) begin
    if (force_fs) begin
      state <= FORCE_FS;
      counter_rst <= 1;
      
      fs_en <= 1;
      adc_soc <= 0;
      b_crc_compute <= 0;
      b_mod_start <= 0;
      b_rom_out_enable <= 0;
      b_crc32_out_enable <= 0;

      rom_addr <= 6'd00;
      bit_addr <= 0;
    end else if (~trig) begin
      state <= IDLE;
      counter_rst <= 1;

      fs_en <= 0;
      adc_soc <= 0;
      b_crc_compute <= 0;
      b_mod_start <= 0;
      b_rom_out_enable <= 0;
      b_crc32_out_enable <= 0;

      rom_addr <= 6'd00;
      bit_addr <= 0;

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

          fs_en <= 0;
          adc_soc <= 0;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;

          rom_addr <= 6'd00;
          bit_addr <= 0;
        end

        B_START : begin
          if (us_counter == T_B_INFO_GOT) begin
            state <= B_INFO_GOT;
            counter_rst <= 1;
          end else begin
            state <= B_START;
            counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 1;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;

          rom_addr <= 6'd26; // 准备写8-bit ADC数据
          bit_addr <= 0;

          if (adc_eoc)
            b_rom[rom_addr] <= adc_data;
          else
            b_rom[rom_addr] <= b_rom[rom_addr];
        end

        B_INFO_GOT : begin
          if (us_counter == T_B_MOD_START) begin
            state <= B_MOD_START;
            counter_rst <= 1;
          end else begin
            state <= B_INFO_GOT;
            counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;
      
          bit_addr <= 0;
          rom_addr <= 6'd00;
        end
        
        B_MOD_START : begin
          if (us_counter == T_B_CRC_START) begin
            state <= B_CRC_START;
            counter_rst <= 1;
            b_fcs_data <= b_fcs_for_xor; //
          end else begin
            state <= B_MOD_START;
            counter_rst <= 0;
          end

          fs_en <= 1;
          adc_soc <= 0;
          b_crc_compute <= 1;
          b_mod_start <= 1;
          b_rom_out_enable <= 1;
          b_crc32_out_enable <= 0;

          if (next_us) begin
            bit_addr <= bit_addr+1;
            if (bit_addr == 7) begin
              rom_addr <= rom_addr+1;
            end else begin
              rom_addr <= rom_addr;
            end  
          end else begin
            bit_addr <= bit_addr;
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

          fs_en <= 1;
          adc_soc <= 0;
          b_crc_compute <= 0;
          b_mod_start <= 1;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 1;

          rom_addr <= 6'd00;
          bit_addr <= 0;          

          if (next_us) begin
            b_fcs_data[31:0] <= {b_fcs_data[30:0], 1'b0};
          end else begin
            b_fcs_data <= b_fcs_data;
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

          fs_en <= 1;
          adc_soc <= 0;
          b_crc_compute <= 0;
          b_mod_start <= 1;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;

          rom_addr <= 6'd00;
          bit_addr <= 0;   
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

          fs_en <= 0;
          adc_soc <= 0;
          b_crc_compute <= 0;
          b_mod_start <= 0;
          b_rom_out_enable <= 0;
          b_crc32_out_enable <= 0;

          rom_addr <= 6'd00;
          bit_addr <= 0;   
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
    .clk(next_us_0),
    .enable(b_mod_start),
    .s_in(b_s_data),
    .s_out(b_mod_out)
  );

  fcs_for_xor fcs_for_xor_inst (
    .clk(next_us_3),
    .enable(b_crc_compute),
    .s_in(b_s_data),
    .val(b_fcs_for_xor)
  );


  initial begin
    // tx_data ^ expected_data
    ////// 固定数据部分 /////
    b_rom[6'd00] <= 8'h00;  // 00 ^ 00
    b_rom[6'd01] <= 8'h00;  // 00 ^ 00
    // SSID Ext
    b_rom[6'd02] <= 8'h00;  // 00 ^ 00
    // SSID len
    b_rom[6'd03] <= 8'h00;  // 10 ^ 10
    // SSID 
    b_rom[6'd04] <= 8'h7c;  // 30 ^ 4c
    b_rom[6'd05] <= 8'h7f;  // 30 ^ 4f
    b_rom[6'd06] <= 8'h73;  // 30 ^ 43
    b_rom[6'd07] <= 8'h64;  // 30 ^ 54
    b_rom[6'd08] <= 8'h71;  // 30 ^ 41
    b_rom[6'd09] <= 8'h77;  // 30 ^ 47
    b_rom[6'd10] <= 8'h00;  // 2d ^ 2d
    b_rom[6'd11] <= 8'h00;  // 30 ^ 30
    b_rom[6'd12] <= 8'h03;  // 30 ^ 33
    b_rom[6'd13] <= 8'h01;  // 30 ^ 31
    b_rom[6'd14] <= 8'h02;  // 30 ^ 32
    b_rom[6'd15] <= 8'h00;  // 2d ^ 2d
    b_rom[6'd16] <= 8'h00;  // 30 ^ 30
    b_rom[6'd17] <= 8'h00;  // 30 ^ 30
    b_rom[6'd18] <= 8'h00;  // 30 ^ 30
    b_rom[6'd19] <= 8'h01;  // 30 ^ 31
    // Vendor Spec info
    b_rom[6'd20] <= 8'h00;  // dd ^ dd
    b_rom[6'd21] <= 8'h00;  // 0c ^ 0c
    b_rom[6'd22] <= 8'h00;  // 54 ^ 54
    b_rom[6'd23] <= 8'h00;  // 4a ^ 4a
    b_rom[6'd24] <= 8'h00;  // 55 ^ 55
    b_rom[6'd25] <= 8'h00;  // 00 ^ 00
    ////// 可变数据部分 /////
    // payload 2
    b_rom[6'd26] <= 8'h00;  // 00 ^ 00
    b_rom[6'd27] <= 8'h00;  // 00 ^ 00
    b_rom[6'd28] <= 8'h00;  // 00 ^ 00
    b_rom[6'd29] <= 8'h00;  // 00 ^ 00
    b_rom[6'd30] <= 8'h00;  // 00 ^ 00
    b_rom[6'd31] <= 8'h00;  // 00 ^ 00
    b_rom[6'd32] <= 8'h00;  // 00 ^ 00
    b_rom[6'd33] <= 8'h00;  // 00 ^ 00
    // crc32 placehold
    b_rom[6'd34] <= 8'h00;
    b_rom[6'd35] <= 8'h00;
    b_rom[6'd36] <= 8'h00;
    b_rom[6'd37] <= 8'h00;

  end

endmodule
