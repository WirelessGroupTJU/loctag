`timescale 1ns/1ns
module loctag_tb;
  reg clk;
  reg reset;
  reg adc_so;
  reg trig;
  reg [1:0] mode;
  reg [1:0] mac_q;


  initial begin
    clk <= 1;
    reset <= 1;
    adc_so <= 0;
    trig <= 0;
    mode <= 2'b10;
    mac_q <= 0;
    #100
    reset <= 0;
    #900
    trig <= 1;
    #736000
    trig <= 0;
    mac_q <= 1;
    #20000
    trig <= 1;
    mac_q <= 2;
    #200000
    trig <= 0;
    mac_q <= 3;
    #19000
    trig <= 1;
    #730000
    trig <= 0;
  end

  always #10 clk <= ~clk;
  
  loctag #(
    .TRIG_DELAY_IN_US(2),
    .TRIG_DELAY_IN_20NS_NEG(25)
  )loctag_inst (
    // 50MHz clock input
    clk,
    reset,
    lt5534_en,
    adc_cs,
    adc_clk,
    adc_so,
    trig,

    ctrl_1,

    mode,
    mac_q,
    led
  );

  

endmodule