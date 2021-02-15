`timescale 1ns/1ns
module loctag_tb;
  reg clk;
  reg reset;
  reg adc_so;
  reg trig;
  reg force_fs;
  reg [1:0] mode;


  initial begin
    clk <= 1;
    reset <= 1;
    adc_so <= 0;
    trig <= 0;
    force_fs <= 0;
    mode <= 2'b10;
    #100
    reset <= 0;
    #900
    trig <= 1;

  end

  always #10 clk <= ~clk;
  
  loctag #(
    .MAC_Q(0)
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

    force_fs,
    mode,
    led
  );

  

endmodule