`timescale 1ns/1ns
module adc7478 # (
  parameter DEFAULT_STATE = 0, // 0: POWER_DOWN, 2: IDLE
  parameter POWER_DOWN_AFTER_CONVERTING = 0
  )
  (  
  input  clk_in,
  input  start,
  output reg cs,
  output clk,
  input  so,
  output reg eoc, // end of conversion
  output reg [7:0] data
  );

  ///////////////// 端口设置 /////////////
  assign clk = clk_in;

  ///////////////// 参数定义 /////////////
  // 定时参数。至少为2，状态转移有额外2个周期的延迟时间
  localparam T_POWER_UPING = 16;
  localparam T_INTERVAL = 2;
  localparam T_LEADING_ZERO = 4;
  localparam T_DATA_OUT = 8;
  localparam T_TRAILING_ZERO = 4;
  localparam T_PD_ENTERING = 4;
  
  // 状态定义
  localparam POWER_DOWN = 0;
  localparam POWER_UPING = 1;

  localparam IDLE = 2;
  localparam LEADING_ZERO = 3;
  localparam DATA_OUT = 4;
  localparam TRAILING_ZERO = 5;
  localparam PD_PREPARE = 6;
  localparam PD_ENTERING = 7;

  ////////////////// 状态机 /////////////////
  // 状态变量
  reg [3:0] state = DEFAULT_STATE;
  
  // 由定时驱动状态的转移 
  reg [7:0] counter = 0;  
  reg counter_rst = 1;
  
  // 定时计数器
  always @(posedge clk_in) begin
    if (counter_rst) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end
  
  // 状态转移
  always @(posedge clk_in) begin
    if (~start) begin
      state <= DEFAULT_STATE;
      counter_rst <= 1;
    end else begin
      case (state)
        POWER_DOWN : begin
          if (~eoc && counter == T_INTERVAL-2) begin
            state <= POWER_UPING;
            counter_rst <= 1;
          end else begin
            state <= POWER_DOWN;
            counter_rst <= 0;
          end
        end

        POWER_UPING : begin
          if (counter == T_POWER_UPING-2) begin
            state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= POWER_UPING;
            counter_rst <= 0;
          end
        end
        
        IDLE : begin
          if (~eoc && counter == T_INTERVAL-2) begin
            state <= LEADING_ZERO;
            counter_rst <= 1;
          end else begin
            state <= IDLE;
            counter_rst <= 0;
          end
        end

        LEADING_ZERO : begin
          if (counter == T_LEADING_ZERO-2) begin
            state <= DATA_OUT;
            counter_rst <= 1;
          end else begin
            state <= LEADING_ZERO;
            counter_rst <= 0;
          end
        end

        DATA_OUT : begin
          if (counter == T_DATA_OUT-2) begin
            state <= TRAILING_ZERO;
            counter_rst <= 1;
          end else begin
            state <= DATA_OUT;
            counter_rst <= 0;
          end
        end

        TRAILING_ZERO : begin
          if (counter == T_TRAILING_ZERO-2) begin
            if (POWER_DOWN_AFTER_CONVERTING) begin
              state <= PD_PREPARE;
              counter_rst <= 1;
            end else begin
              state <= IDLE;
              counter_rst <= 1;
            end
          end else begin
            state <= TRAILING_ZERO;
            counter_rst <= 0;
          end
        end

        PD_PREPARE : begin
          if (counter == T_INTERVAL-2) begin
            state <= PD_ENTERING;
            counter_rst <= 1;
          end else begin
            state <= PD_PREPARE;
            counter_rst <= 0;
          end
        end

        PD_ENTERING : begin
          if (counter == T_PD_ENTERING-2) begin
            state <= POWER_DOWN;
            counter_rst <= 1;
          end else begin
            state <= PD_ENTERING;
            counter_rst <= 0;
          end
        end
        
        default: begin
          state <= DEFAULT_STATE;
          counter_rst <= 1;
        end

      endcase
    end // if-else-end  
  end

  // 动作
  always @(posedge clk_in) begin
    if (~start) begin
      cs <= 1;
      data <= 8'hFF;
      eoc <= 0;
    end else begin
      case (state)
        POWER_DOWN, IDLE, PD_PREPARE: begin
          cs <= 1;
          data <= data;
          eoc <= eoc;
        end
        DATA_OUT: begin
          cs <= 0;
          data <= #5 {data[6:0], so};
          eoc <= eoc;
        end
        POWER_UPING, LEADING_ZERO, PD_ENTERING: begin
          cs <= 0;
          data <= data;
          eoc <= eoc;
        end
        TRAILING_ZERO : begin
          cs <= 0;
          data <= data;
          eoc <= 1;
        end
        default: begin
          cs <= 1;
          data <= data;
          eoc <= eoc;
        end
      
      endcase
    end
  end

endmodule