`timescale 1ns/1ns
module mac # (
    parameter [15:0] MAC_SEED = 16'h4C06,
    parameter MAC_Q = 0  // 窗口大小指数, MAC协议将生成Q位的随机数R，并在R为0时执行调制
  )
  (
  input  clk,
  input  enable,
  output out
  );
  
  reg  [16:0] pn = {MAC_SEED, 1'b0};  // pn[0]始终保持0以处理边界问题
  // x^16 + x^14 + x^13 + x^11 + 1
  assign out = ~| pn[MAC_Q:0]; // Q为0时始终进行调制
  
  always @(posedge clk) begin
    if (~enable) begin
      pn <= {MAC_SEED, 1'b0};
    end else begin
      pn[16:1] <= {pn[15:1], pn[11]^pn[13]^pn[14]^pn[16]};
    end
  end
endmodule
