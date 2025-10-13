module top_alu (
    input         CLK100,
    input  [15:0] sw_i,
    output [15:0] led_o
);

  alu i_alu
  (
    .a_i      ( sw_i  [ 4: 0] ),
    .b_i      ( sw_i  [ 9: 5] ),
    .alu_op_i ( sw_i  [15:10] ),
    .result_o ( led_o [ 9: 0] ),
    .flag_o   ( led_o [   10] )
  );

endmodule
