module fulladder32 (
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  logic        carry_i,
  output logic [31:0] sum_o,
  output logic        carry_o
);

  wire [7:0] carry;
  assign carry_o = carry [7];

  fulladder4 i0_fa4
  (
    .a_i     ( a_i   [3:0] ),
    .b_i     ( b_i   [3:0] ),
    .carry_i ( carry_i     ),
    .sum_o   ( sum_o [3:0] ),
    .carry_o ( carry [0  ] )
  );

  fulladder4 i1_fa4
  (
    .a_i     ( a_i   [7:4] ),
    .b_i     ( b_i   [7:4] ),
    .carry_i ( carry [0  ] ),
    .sum_o   ( sum_o [7:4] ),
    .carry_o ( carry [1  ] )
  );

  fulladder4 i2_fa4
  (
    .a_i     ( a_i   [11:8] ),
    .b_i     ( b_i   [11:8] ),
    .carry_i ( carry [1   ] ),
    .sum_o   ( sum_o [11:8] ),
    .carry_o ( carry [2   ] )
  );

  fulladder4 i3_fa4
  (
    .a_i     ( a_i   [15:12] ),
    .b_i     ( b_i   [15:12] ),
    .carry_i ( carry [2    ] ),
    .sum_o   ( sum_o [15:12] ),
    .carry_o ( carry [3    ] )
  );

  fulladder4 i4_fa4
  (
    .a_i     ( a_i   [19:16] ),
    .b_i     ( b_i   [19:16] ),
    .carry_i ( carry [3    ] ),
    .sum_o   ( sum_o [19:16] ),
    .carry_o ( carry [4    ] )
  );

  fulladder4 i5_fa4
  (
    .a_i     ( a_i   [23:20] ),
    .b_i     ( b_i   [23:20] ),
    .carry_i ( carry [4    ] ),
    .sum_o   ( sum_o [23:20] ),
    .carry_o ( carry [5    ] )
  );

  fulladder4 i6_fa4
  (
    .a_i     ( a_i   [27:24] ),
    .b_i     ( b_i   [27:24] ),
    .carry_i ( carry [5    ] ),
    .sum_o   ( sum_o [27:24] ),
    .carry_o ( carry [6    ] )
  );

  fulladder4 i7_fa4
  (
    .a_i     ( a_i   [31:28] ),
    .b_i     ( b_i   [31:28] ),
    .carry_i ( carry [6    ] ),
    .sum_o   ( sum_o [31:28] ),
    .carry_o ( carry [7    ] )
  );

endmodule
