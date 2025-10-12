module fulladder4 (
  input  logic [3:0] a_i,
  input  logic [3:0] b_i,
  input  logic       carry_i,
  output logic [3:0] sum_o,
  output logic       carry_o
);

  wire [3:0] carry;
  assign carry_o = carry [3];

  fulladder i0_fa
  (
    .a_i     ( a_i   [0] ),
    .b_i     ( b_i   [0] ),
    .carry_i ( carry_i   ),
    .sum_o   ( sum_o [0] ),
    .carry_o ( carry [0] )
  );

  fulladder i1_fa
  (
    .a_i     ( a_i   [1] ),
    .b_i     ( b_i   [1] ),
    .carry_i ( carry_i   ),
    .sum_o   ( sum_o [1] ),
    .carry_o ( carry [1] )
  );

  fulladder i2_fa
  (
    .a_i     ( a_i   [2] ),
    .b_i     ( b_i   [2] ),
    .carry_i ( carry_i   ),
    .sum_o   ( sum_o [2] ),
    .carry_o ( carry [2] )
  );

  fulladder i3_fa
  (
    .a_i     ( a_i   [3] ),
    .b_i     ( b_i   [3] ),
    .carry_i ( carry_i   ),
    .sum_o   ( sum_o [3] ),
    .carry_o ( carry [3] )
  );

endmodule
