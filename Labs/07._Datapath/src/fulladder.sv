module fulladder (
  input  logic a_i,
  input  logic b_i,
  input  logic carry_i,
  output logic sum_o,
  output logic carry_o
);

  assign { carry_o, sum_o } = a_i + b_i + carry_i;

endmodule
