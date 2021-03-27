`timescale 1ns/1ns
module loctag # (
    // 标签ID，值可变，长度不能变
    parameter TAG_ID = "LOCTAG-10000",
    // MAC协议模块伪随机数生成器使用的种子，应为每个标签设置不同的值
    parameter [15:0] MAC_SEED = 16'h4C06,
    // 触发延迟补偿，提前 (TRIG_DELAY_IN_US - 0.02*TRIG_DELAY_IN_20NS)微秒
    parameter integer TRIG_DELAY_IN_US = 2,  // 提前多少us开始调制过程，以补偿TRIG检测延迟
    parameter integer TRIG_DELAY_IN_20NS_NEG = 35  // 在us级补偿的基础上延迟多少个20ns开始调制，取值范围为1到48
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

  input  [1:0] mode,
  input  [1:0] mac_q,
  output smoothed_trig,
  output led
  );

  ///////////////// 端口设置 /////////////
  assign lt5534_en = 1'b1;
  assign led = (mode==2'b11)? 1'b1: (mode==2'b00)? 1'b0: trig;
  // smoothed_trig signal filter
  localparam TRIG_FILTER_LEN = 28;
  reg  [TRIG_FILTER_LEN-1:0] trig_filter = 0;
  assign smoothed_trig = |trig_filter;
  ///////////////// 参数定义 /////////////  

  // 定时参数
  // 11b, 1Mbps
  // PLCP header 144+48, before_mod: 4*8=32, mod: 60*8=480, fcs: 32.
  // summary: GET_RSS<3> + DELAY_COMPENSATION<9> + ZERO_MOD<(192-3-9)+(4*8)=212> + DATA_MOD<(60*8)>+FILL_FCS<32> = 704+32 = 736us
  localparam T_B_GET_RSS = 3;
  localparam T_B_DELAY_COMPENSATION = 9; // 检测延迟
  localparam T_B_ZERO_MOD = 452;
  localparam T_B_DATA_MOD = 240;
  localparam T_B_FILL_FCS = 32;
  localparam [19:0] T_B_PACKET_DURATION = (736-TRIG_DELAY_IN_US)*50 + TRIG_DELAY_IN_20NS_NEG;

  localparam T_WAIT_FOR_11N_TIMEOUT = 2100;  // 以微秒记
  // 11n. see TableIEEE Std 802.11-2016, Figure 19-4
  // for MF, Preamble>=10sym(20us); for GF, Preamble>=6sym(24us)
  localparam T_N_GET_RSS = 3;
  localparam [19:0] T_N_PACKET_DURATION = (736-TRIG_DELAY_IN_US)*50 + TRIG_DELAY_IN_20NS_NEG;

  ///////////////// 状态定义 ///////////////
  localparam IDLE = 0;
  localparam FORCE_FS = 1;
  localparam DISABLE = 2;
  // 请求包，2~9

  // 11b, 10~17
  localparam B_GET_RSS = 10;
  localparam B_TIMING_CORRECT = 11;
  localparam B_ZERO_MOD = 12;  // 已获得RSS和MAC协议运行结果
  localparam B_DATA_MOD = 13;
  localparam B_FILL_FCS = 14;
  localparam B_WAIT_END = 15; // TRIG仍然为高，等待
  // The gap inside the time slot
  localparam WAIT_FOR_11N = 18; // 等待紧随的11n包
  // 11n, 18~25
  // localparam N_GET_RSS = 20;
  localparam N_WAIT_END = 22;

  //////////////////// 11b 计时器 /////////////////////
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

  //////////////////// 包长计时器 (us) /////////////////////
  reg  [19:0] p_20ns_counter = 0;
  reg  p_counter_rst = 0;
  always @(posedge clk) begin
    if (reset) begin
      p_20ns_counter <= 0;
    end else if (p_counter_rst) begin
      p_20ns_counter <= 0;
    end else begin
      p_20ns_counter <= p_20ns_counter + 1;
    end 
  end

  ////////////////////// 状态机 /////////////////
  // 状态变量
  reg [4:0] state = IDLE;
  // 状态信号
  wire adc_eoc; // ADC转换完成
  wire mac_out; 
  // 控制信号
  reg  active_this_time = 0; 
  reg  fs_en = 0;
  reg  adc_soc = 0;
  
  reg  crc_compute_enable = 0;
  reg  mod_enable = 0;
  reg  rom_out_enable = 0;
  reg  crc32_out_enable = 0;
  wire mod_out;
  wire mod_invert_tmp = mod_enable & mod_out;
  // 11b
  reg  b_mod_invert = 0;
  always @(posedge b_next_symbol_5) begin
    b_mod_invert <= mod_invert_tmp; // 防止毛刺
  end
  
  // 反射开关控制信号 
  wire mod_invert = b_mod_invert;
  assign ctrl_1 = (clk & fs_en) ^ mod_invert;  
  
  ////////// 数据 /////////
  // adc
  wire [7:0] adc_data;
  // ROM Access
  localparam B_ADDR_START = 6'd00;

  localparam ADDR_WIDTH = 6;
  localparam ROM_SIZE = 2**ADDR_WIDTH;
  reg  [ADDR_WIDTH-1:0] rom_addr = 0;
  reg  [0:2] bit_addr = 0;
  // ROM
  reg  [7:0] rom[0:ROM_SIZE-1];
  wire [7:0] rom_data = rom[rom_addr];
 
  // fcs
  wire [31:0] fcs_for_xor;
  reg  [31:0] fcs_data = 0;

  // 输入到调制器的串行数据
  wire s_data = (rom_out_enable & rom_data[bit_addr])
                  | (crc32_out_enable & fcs_data[31]);

  // 状态机
  always @(posedge clk) begin
    if (mode == 2'b00) begin
      state <= DISABLE;
      active_this_time <= 0;
      fs_en <= 0;
      adc_soc <= 0;

      b_counter_rst <= 1;
      p_counter_rst <= 1;
      crc_compute_enable <= 0;
      mod_enable <= 0;
      rom_out_enable <= 0;
      crc32_out_enable <= 0;
      rom_addr <= 6'd00;
      bit_addr <= 0;

    end else if (mode == 2'b11) begin
      state <= FORCE_FS;
      active_this_time <= 0;
      fs_en <= 1;
      adc_soc <= 0;

      b_counter_rst <= 1;
      p_counter_rst <= 1;
      crc_compute_enable <= 0;
      mod_enable <= 0;
      rom_out_enable <= 0;
      crc32_out_enable <= 0;
      rom_addr <= 6'd00;
      bit_addr <= 0;

    end else begin
      case (state)
        IDLE : begin
          if (smoothed_trig) begin
            if (mac_out) begin
              state <= B_GET_RSS;
              active_this_time <= 1;
            end else begin
              state <= B_WAIT_END;
              active_this_time <= 0;
            end
          end else begin
            state <= IDLE;
            active_this_time <= 0;
          end
          
          b_counter_rst <= 1;
          p_counter_rst <= 1;

          fs_en <= 0;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;
        end

        B_GET_RSS : begin
          p_counter_rst <= 0;
          if (smoothed_trig) begin
            if (b_symbol_counter == T_B_GET_RSS) begin
              state <= B_TIMING_CORRECT;
              b_counter_rst <= 1;
            end else begin
              state <= B_GET_RSS;
              b_counter_rst <= 0;
            end
          end else begin
            state <= IDLE;
            b_counter_rst <= 1;
          end

          fs_en <= 1;
          adc_soc <= 1;

          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START+6'd22;
          bit_addr <= 0;
          if (adc_eoc)
            rom[rom_addr] <= adc_data;
          else
            rom[rom_addr] <= rom[rom_addr];
        end

        B_TIMING_CORRECT : begin
          p_counter_rst <= 0;
          if (smoothed_trig) begin
            if (b_symbol_counter == T_B_DELAY_COMPENSATION-TRIG_DELAY_IN_US && b_divide_counter==TRIG_DELAY_IN_20NS_NEG) begin
              state <= B_ZERO_MOD;
              b_counter_rst <= 1;
            end else begin
              state <= B_TIMING_CORRECT;
              b_counter_rst <= 0;
            end
          end else begin
            state <= IDLE;
            b_counter_rst <= 1;
          end

          fs_en <= 1;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;
        end

        B_ZERO_MOD : begin
          p_counter_rst <= 0;
          if (smoothed_trig) begin
            if (b_symbol_counter == T_B_ZERO_MOD) begin
              state <= B_DATA_MOD;
              b_counter_rst <= 1;
            end else begin
              state <= B_ZERO_MOD;
              b_counter_rst <= 0;
            end
          end else begin
            state <= IDLE;
            b_counter_rst <= 1;
          end

          fs_en <= 1;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 1;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;
        end
        
        B_DATA_MOD : begin
          p_counter_rst <= 0;
          if (smoothed_trig) begin
            if (b_symbol_counter == T_B_DATA_MOD) begin
              state <= B_FILL_FCS;
              b_counter_rst <= 1;
              fcs_data <= fcs_for_xor;
              $display("FCS: %b, %x", fcs_for_xor, fcs_for_xor);
            end else begin
              state <= B_DATA_MOD;
              b_counter_rst <= 0;
            end
          end else begin
            state <= IDLE;
            b_counter_rst <= 1;
          end

          fs_en <= 1;
          adc_soc <= 0;

          crc_compute_enable <= 1;
          mod_enable <= 1;
          rom_out_enable <= 1;
          crc32_out_enable <= 0;
          if (b_next_symbol) begin
            bit_addr <= bit_addr+1;
            if (bit_addr == 7) begin
              rom_addr <= rom_addr+1;
            end else begin
              rom_addr <= rom_addr;
            end  
          end else begin
            bit_addr <= bit_addr;
            rom_addr <= rom_addr;
          end
      
        end
        
        B_FILL_FCS : begin
          p_counter_rst <= 0;
          if (smoothed_trig) begin
            if (b_symbol_counter == T_B_FILL_FCS) begin
              state <= B_WAIT_END;
              b_counter_rst <= 1;
            end else begin
              state <= B_FILL_FCS;
              b_counter_rst <= 0;
            end
          end else begin
            state <= B_WAIT_END;
            b_counter_rst <= 1;
          end

          fs_en <= 1;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 1;
          rom_out_enable <= 0;
          crc32_out_enable <= 1;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;   

          if (b_next_symbol) begin
            fcs_data[31:0] <= {fcs_data[30:0], 1'b0};
          end else begin
            fcs_data <= fcs_data;
          end
        end

        B_WAIT_END : begin
          b_counter_rst <= 1;
          if (~smoothed_trig) begin
            $display("B: %b, %b", p_20ns_counter, p_20ns_counter[19:8]);
            $display("p: %b, %b", T_B_PACKET_DURATION, T_B_PACKET_DURATION[19:8]);
            if (mode==2'b10 && p_20ns_counter[19:8] == T_B_PACKET_DURATION[19:8]) begin
              state <= WAIT_FOR_11N; 
            end else begin
              state <= IDLE;
            end
            p_counter_rst <= 1;
          end else begin
            state <= B_WAIT_END;
            p_counter_rst <= 0;
          end

          fs_en <= active_this_time;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;   
        end

        WAIT_FOR_11N : begin
          b_counter_rst <= 1;
          if (smoothed_trig) begin
            state <= N_WAIT_END;
            p_counter_rst <= 1;
          end else begin
            if (p_20ns_counter == T_WAIT_FOR_11N_TIMEOUT*50) begin
              state <= IDLE;  // 超时，复位
            end else begin
              state <= WAIT_FOR_11N; 
            end
            p_counter_rst <= 0;
          end

          fs_en <= 0;
          adc_soc <= 0;

          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;   
        end

        // N_GET_RSS : begin
        //   p_counter_rst <= 0;
        //   if (smoothed_trig) begin
        //     if (p_20ns_counter == T_N_GET_RSS) begin
        //       state <= N_WAIT_END;
        //       b_counter_rst <= 1;
        //     end else begin
        //       state <= N_GET_RSS;
        //       b_counter_rst <= 0;
        //     end
        //   end else begin
        //     state <= IDLE;
        //     b_counter_rst <= 1;
        //   end

        //   fs_en <= 1;
        //   adc_soc <= 1;

        //   crc_compute_enable <= 0;
        //   mod_enable <= 0;
        //   rom_out_enable <= 0;
        //   crc32_out_enable <= 0;
        //   rom_addr <= B_ADDR_START+6'd24;
        //   bit_addr <= 0;
        //   if (adc_eoc)
        //     rom[rom_addr] <= adc_data;
        //   else
        //     rom[rom_addr] <= rom[rom_addr];
        // end

        N_WAIT_END : begin
          p_counter_rst <= 0;
          b_counter_rst <= 1;
          if (~smoothed_trig) begin
            state <= IDLE;     
          end else begin
            state <= N_WAIT_END;
          end

          fs_en <= active_this_time;
          adc_soc <= 0;
          
          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
          rom_addr <= B_ADDR_START;
          bit_addr <= 0;   
        end
        
        default: begin
          state <= IDLE;
          fs_en <= 0;
          adc_soc <= 0;

          b_counter_rst <= 1;
          p_counter_rst <= 1;
          crc_compute_enable <= 0;
          mod_enable <= 0;
          rom_out_enable <= 0;
          crc32_out_enable <= 0;
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

  // trig_filter
  always @(posedge clk_12mhz) trig_filter[TRIG_FILTER_LEN-1:0] = {trig_filter[TRIG_FILTER_LEN-2:0], trig};

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
    .enable(mod_enable),
    .s_in(s_data),
    .s_out(mod_out)
  );

  fcs_for_xor fcs_for_xor_inst (
    .clk(b_next_symbol_3),
    .enable(crc_compute_enable),
    .s_in(s_data),
    .val(fcs_for_xor)
  );

  mac # (
    .MAC_SEED(MAC_SEED)
  ) mac_inst
  (
    .clk(clk),
    .enable(1'b1),
    .mac_q(mac_q),
    .mac_out(mac_out)
  );

  integer i;
  parameter SSID_PADDING = "000000-00000";
  initial begin

    /////////////// 11b data section ////////////////
    // tag_data = tx_data ^ expected_data

    for (i = 0; i<4; i=i+1) begin
        rom[i] <= 8'h00;
    end
    // 初始化标签ID，标签ID共12字节
    for (i = 0; i<12; i=i+1) begin
        rom[4+12-i-1] <= SSID_PADDING[i*8+:8] ^ TAG_ID[i*8+:8];
    end
    for (i = 4+12; i<ROM_SIZE; i=i+1) begin
        rom[i] <= 8'h00;
    end
    /////////////// 11n data section ////////////////

  end

endmodule
