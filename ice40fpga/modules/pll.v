module pll (
  // 16MHz clock input
  input  clk_in,
  // 50MHz clock output
  output clk_out,
  // high-level valid
  output reset,
  );

  /////////////////////////////////////////
  // generate 50 mhz clock
  /////////////////////////////////////////
  wire lock;
  assign reset = !lock;
  
  SB_PLL40_CORE #(
    .DIVR(4'b0000),
    .DIVF(7'b011_0001),
    .DIVQ(3'b100),
    .FILTER_RANGE(3'b001),
    .FEEDBACK_PATH("SIMPLE"),
    .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
    .FDA_FEEDBACK(4'b0000),
    .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
    .FDA_RELATIVE(4'b0000),
    .SHIFTREG_DIV_MODE(2'b00),
    .PLLOUT_SELECT("GENCLK"),
    .ENABLE_ICEGATE(1'b0)
  ) usb_pll_inst (
    .REFERENCECLK(clk_in),
    .PLLOUTCORE(clk_out),
    .PLLOUTGLOBAL(),
    .EXTFEEDBACK(),
    .DYNAMICDELAY(),
    .RESETB(1'b1),
    .BYPASS(1'b0),
    .LATCHINPUTVALUE(),
    .LOCK(lock),
    .SDI(),
    .SDO(),
    .SCLK()
  );

endmodule
