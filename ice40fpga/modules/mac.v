`timescale 1ns/1ns
module mac # (
    parameter [15:0] MAC_SEED = 16'h4C06
  )
  (
  input  clk,
  input  enable,
  input  [1:0] mac_q, // 窗口大小指数, MAC协议将生成Q位的随机数R，并在R为0时执行调制
  output mac_out
  );
  
  wire [2:0] mask = (mac_q == 2'd0) ? 3'b000 :
                    (mac_q == 2'd1) ? 3'b001 :
                    (mac_q == 2'd2) ? 3'b011 :
                    3'b111;
  reg  [15:0] pn = MAC_SEED;
  // x^16 + x^14 + x^13 + x^11 + 1
  assign mac_out = ~|(pn[2:0]&mask[2:0]); // Q为0时始终进行调制
  
  always @(posedge clk) begin
    if (~enable) begin
      pn <= MAC_SEED;
    end else begin
      pn[15:0] <= {pn[14:0], pn[10]^pn[12]^pn[13]^pn[15]};
    end
  end
endmodule
