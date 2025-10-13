module top_fulladder32 (
    input CLK100,
    input [15:0] SW,
    output [15:0] LED
);

  fulladder32 i_fa32
  (
    .a_i     ( { 24'd0, SW[ 7:0] } ),
    .b_i     ( { 24'd0, SW[15:8] } ),
    .carry_i ( 1'b0                ),
    .sum_o   ( LED                 ),
    .carry_o (                     )
  );

endmodule
