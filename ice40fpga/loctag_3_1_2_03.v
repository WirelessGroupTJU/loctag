`timescale 1ns/1ns
module loctag_3_1_2_03 (
  // 16MHz clock input
  input  pin_clk,
  // detector
  output pin_lt5534_en,
  output pin_adc_cs,
  output pin_adc_clk,
  input  pin_adc_so,
  input  pin_trig,
  // reflector
  output pin_ctrl_1,
  // user interface io
  output pin_led,

  input  pin_key_1,
  input  pin_key_2,
  input  pin_key_3,
  input  pin_key_4,

  // output pin_mio_1,
  // output pin_mio_2,
  // output pin_mio_3,
  // output pin_mio_4,
  // output pin_mio_7,
  // output pin_mio_8,
  // output pin_mio_9,
  input pin_mio_10
  );

  // 模式配置输入
  wire [1:0] mode = ~(pin_key_1&pin_key_2)? {~pin_key_1, ~pin_key_2}: pin_mio_10? 2'b11: 2'b00;
  wire [1:0] mac_q = {~pin_key_3, ~pin_key_4};
   // 时钟与复位
  wire clk;
  wire reset; 
  pll pll_inst (
    .clk_in(pin_clk),
    .clk_out(clk),
    .reset(reset)
  );

  wire trig = ~pin_trig;
  wire led;
  
  loctag  # (
    .TAG_ID("LOCTAG-10003"),
    .MAC_SEED(16'h7654),
    .TRIG_DELAY_IN_US(2),
    .TRIG_DELAY_IN_20NS_NEG(25)
  ) loctag_inst (
    // 50MHz clock input
    .clk(clk),
    .reset(reset),
    .lt5534_en(pin_lt5534_en),
    .adc_cs(pin_adc_cs),
    .adc_clk(pin_adc_clk),
    .adc_so(pin_adc_so),
    .trig(trig),

    .ctrl_1(pin_ctrl_1),

    .mode(mode),
    .mac_q(mac_q),
    .led(led)
  );

  assign pin_led = ~led;

endmodule
