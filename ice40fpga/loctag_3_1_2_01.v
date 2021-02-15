`timescale 1ns/1ns
module loctag_3_1_2_01 (
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
  input  pin_key_3
  // input  pin_key_4,

  // output pin_mio_1,
  // output pin_mio_2,
  // output pin_mio_3,
  // output pin_mio_4,
  // output pin_mio_7,
  // output pin_mio_8,
  // output pin_mio_9,
  // output pin_mio_10,
  );

  // 模式配置输入
  wire force_fs = ~pin_key_1;
  wire [1:0] mode = {~pin_key_2, ~pin_key_3};
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
    .TAG_ID("LOCTAG-0312-0001"),
    .MAC_SEED(16'h7654),
    .MAC_Q(2)
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

    .force_fs(force_fs),
    .mode(mode),
    .led(led)
  );

  assign pin_led = ~led;

endmodule
