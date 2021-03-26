`timescale 1ns/1ns

module fcs_for_xor # (
  parameter STATE_INIT_VAL = 32'h00000000
  )
  (
  input clk,
  input enable,
  input s_in,
  output [31:0] val
  );
  
  localparam POLY = 32'h04C11DB7;
  reg  [31:0] state = STATE_INIT_VAL; // 计算输入序列s_in的CRC32值,位31是最高项系数
  
  assign val = state;

  always @(posedge clk) begin
    if (~enable) begin
      state <= #2 STATE_INIT_VAL;
    end else begin
      state[31:0] <= #2 {state[30:0], 1'b0} ^ (POLY&{32{s_in^state[31]}});
    end
  end

endmodule