module daisy_chain (
    input               clk_i,
    input               rst_i,
    input  logic [15:0] masked_irq_i,
    input  logic        irq_ret_i,
    input  logic        ready_i,
    output logic        irq_o,
    output logic [31:0] irq_cause_o,
    output logic [15:0] irq_ret_o
);

  // V3rilator has issues with ready,
  // I believe this is fine in this scenario.

  // verilator lint_off UNOPTFLAT
  logic [15:0] ready;
  // verilator lint_on UNOPTFLAT
  logic [15:0] cause;

  assign ready [0] = ready_i;

  genvar i;
  generate
    for (i = 0; i < 15; i ++)
      assign ready [i + 1] = ready [i] &~ cause [i];

    for (i = 0; i < 16; i ++)
      assign cause [i] = masked_irq_i [i] & ready [i];
  endgenerate

  // ------------------------
  // Interrupts tracker logic

  logic [15:0] irq_h;  // _h stands for _handling

  always_ff @ (posedge clk_i)
    if (rst_i)
      irq_h <= 16'd0;
    else if (irq_o)
      irq_h <= cause;

  // ------------
  // Output logic

  assign irq_o = | cause;
  assign irq_cause_o = { 12'h800, cause, 4'b0000 };
  assign irq_ret_o = irq_ret_i ? irq_h : 16'd0;

endmodule
