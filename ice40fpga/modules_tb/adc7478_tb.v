`timescale 1ns/1ns
module adc7478_tb;
  // 信号定义
  reg clk_in;
  reg start;
  wire cs;
  wire clk;
  reg  so;
  wire eoc;
  wire [7:0] data;

  initial begin
    clk_in <= 1;
    start <= 0;
    so <= 1'b0;
    #200
    start <= 1;
    #4000
    start <= 0;
  end

  always #25 clk_in <= ~clk_in;
    
  // 模块实例化
  adc7478 # (
    .DEFAULT_STATE(0),
    .POWER_DOWN_AFTER_CONVERTING(0)
  ) adc7478_inst (
    // 50MHz clock input
    .clk_in,
    .start,
    .cs,
    .clk,
    .so,
    .eoc, // end of conversion
    .data
  );

endmodule
