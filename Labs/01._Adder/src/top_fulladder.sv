module top_fulladder (
    input CLK100,
    input [15:0] SW,
    output [15:0] LED
);

  assign LED [15:2] = 14'd0;

  fulladder i_fa
  (
    .a_i     ( SW  [1] ),
    .b_i     ( SW  [2] ),
    .carry_i ( SW  [0] ),
    .sum_o   ( LED [0] ),
    .carry_o ( LED [1] )
  );

endmodule
