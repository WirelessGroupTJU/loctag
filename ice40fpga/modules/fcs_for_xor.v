`timescale 1ns/1ns

module fcs_for_xor # (
  parameter STATE_INIT_VAL = 32'hffffffff
  )
  (
  input clk,
  input enable,
  input s_in,
  output [31:0] fcs_for_xor
  );
  
  localparam POLY = 32'h04C11DB7;
  reg  [31:0] state = STATE_INIT_VAL; // 计算输入序列s_in的CRC32值
  reg  [31:0] state_zeros_in = STATE_INIT_VAL; // 计算与s_in长度相同的0序列的CRC32
  
  assign fcs_for_xor = state ^ state_zeros_in; // ~state ^ ~state_zeros_in;

  always @(negedge clk) begin
    if (~enable) begin
      state <= #2 STATE_INIT_VAL;
      state_zeros_in <= #2 STATE_INIT_VAL;
    end else begin
      state[31:0] <= #2 {state[30:0], 1'b0} ^ (POLY&{32{s_in^state[31]}});
      state_zeros_in[31:0] <= #2 {state_zeros_in[30:0], 1'b0} ^ (POLY&{32{state_zeros_in[31]}});
    end
  end

endmodule