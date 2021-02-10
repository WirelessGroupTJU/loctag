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
  output reg led
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

  // 调制数据
  localparam B_LEN = 8;
  reg  [B_LEN-1:0] b_data = 8'h34;
  wire b_s_dat = b_data[B_LEN-1];
  wire [31:0] fcs_for_xor;
  reg  [31:0] b_fcs_data = 0;

  localparam N_LEN = 8;
  reg [N_LEN-1:0] n_data;
  wire n_s_dat = n_data[N_LEN-1];
  
  always @(posedge clk) begin
    case (state)
      B_START : begin
        fs_en <= 1;
        mod_invert <= 0;
        b_mod_start <= 0;
        b_crc_compute <= 0;
        adc_soc <= 1;
        rss <= 8'hff;
      end

      B_INFO_GOT : begin
        fs_en <= 1;
        mod_invert <= 0;
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
        if (next_us)
          b_data[B_LEN-1:0] <= {b_data[B_LEN-2:0], 1'b0};
        else
          b_data <= b_data;
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
endmodule
