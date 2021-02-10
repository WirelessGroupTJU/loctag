`timescale 1ns/1ns
module fcs_for_xor_tb;
  // 信号定义
  reg clk;
  reg enable;
  wire s_in;
  wire [31:0] val;

  localparam  P = 20;
  reg  [15:0] data = 16'h1100; // 120031ef;
  initial begin
    clk <= 1;
    enable <= 0;
    // s_in <= 1'b0;
    #200
    enable <= 1;
    #(P*16)
    enable <= 0;
  end

  always #(P/2) clk <= ~clk;
  assign s_in = data[15];
  always @(posedge clk ) begin
    if (~enable) begin
      data <= #2 data;
    end else begin
      data <= #2 {data[14:0], 1'b0};
    end
  end

  // 模块实例化
  fcs_for_xor # (
  .STATE_INIT_VAL(32'hffffffff)
  ) fcs_for_xor_inst
  (
  clk,
  enable,
  s_in,
  val
  );

endmodule
