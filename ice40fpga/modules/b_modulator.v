`timescale 1ns/1ns

module b_modulator # (
  parameter SCRAMBLER_INIT_VAL = 8'h00,
  parameter DBPSK_INIT_VAL = 1'b0
  )
  (
  input clk,
  input enable,
  input s_in,
  output s_out
  );
  
  reg  [7:0] scrambler = SCRAMBLER_INIT_VAL;
  reg  [0:0] dbpsk = DBPSK_INIT_VAL;
  // y[k] = x[k] + y[k-4] + y[k-7]
  wire scrambler_out = s_in ^ scrambler[3] ^ scrambler[6];
  // y[k] = x[k] - y[k-1]
  assign s_out = scrambler_out ^ dbpsk[0];
  
  always @(posedge clk) begin
    if (~enable) begin
      scrambler <= SCRAMBLER_INIT_VAL;
      dbpsk <= DBPSK_INIT_VAL;
    end else begin
      scrambler[6:0] <= {scrambler[5:0], scrambler_out};
      dbpsk[0] <= s_out;
    end
  end

endmodule
