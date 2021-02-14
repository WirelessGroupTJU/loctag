`timescale 1ns/1ns

module n_disturber # (
    parameter PN_INIT_VAL = 8'b0100_0101
  )
  (
  input clk,
  input enable,
  output s_out
  );
  
  reg  [7:0] pn = PN_INIT_VAL;
  // 1 + x^4 +x^5 + x^6 + x^8
  assign s_out = enable & (pn[3] ^ pn[4] ^ pn[5] ^ pn[7]);
  
  always @(posedge clk) begin
    if (~enable) begin
      pn <= PN_INIT_VAL;
    end else begin
      pn[7:0] <= {pn[6:0], s_out};
    end
  end

endmodule
