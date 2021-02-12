`timescale 1ns/1ns
module mac_tb ;

reg clk;
reg enable;
wire out;

initial begin
    clk <= 1;
    enable <= 0;
    # 100
    enable <= 1;
    // # 9000
end

always #10 clk <= ~clk;

  mac # (
    .MAC_SEED(16'h4C06),
    .MAC_Q(0)
  ) mac_inst
  (
    clk,
    enable,
    out
  );

endmodule