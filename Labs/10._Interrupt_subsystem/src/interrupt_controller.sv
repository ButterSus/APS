module interrupt_controller (
    input logic clk_i,
    input logic rst_i,
    input logic exception_i,
    input logic irq_req_i,
    input logic mie_i,
    input logic mret_i,

    output logic        irq_ret_o,
    output logic [31:0] irq_cause_o,
    output logic        irq_o
);

  // ---------
  // Registers

  logic exc_h, irq_h;  // (_h stands for _handling)

  always_ff @ ( posedge clk_i )
    if (rst_i)
      exc_h <= 1'b0;
    else if (mret_i)
      exc_h <= 1'b0;
    else if (exception_i)
      exc_h <= 1'b1;

  always_ff @ ( posedge clk_i )
    if (rst_i)
      irq_h <= 1'b0;
    else if (mret_i)
      irq_h <= 1'b0;
    else if (irq_o)
      irq_h <= 1'b1;

  // ------------
  // Output logic

  assign irq_o = (irq_req_i & mie_i) &~ (exc_h | irq_h);
  assign irq_ret_o = mret_i &~ (exc_h | exception_i);
  assign irq_cause_o = 32'h8000_0010;

endmodule
