module interrupt_controller (
    input logic        clk_i,
    input logic        rst_i,
    input logic        exception_i,
    input logic [15:0] irq_req_i,
    input logic [15:0] mie_i,
    input logic        mret_i,

    output logic [15:0] irq_ret_o,
    output logic [31:0] irq_cause_o,
    output logic        irq_o
);

  // We don't want warnings from vivado, do ya?
  // Follow principle: move output port nets to top.

  wire        dc_irq;
  wire [31:0] dc_irq_cause;
  wire [15:0] dc_irq_ret_o;

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

  // ----------------------------
  // Integration with daisy chain

  wire [15:0] dc_masked_irq;
  wire        dc_irq_ret_i;
  wire        dc_ready;

  assign dc_masked_irq = irq_req_i & mie_i;
  assign dc_irq_ret_i = mret_i &~ (exc_h | exception_i);
  assign dc_ready = ~exception_i & ~exc_h & ~irq_h;

  daisy_chain i_dc
  (
    .clk_i        ( clk_i         ),
    .rst_i        ( rst_i         ),
    .masked_irq_i ( dc_masked_irq ),
    .irq_ret_i    ( dc_irq_ret_i  ),
    .ready_i      ( dc_ready      ),
    .irq_o        ( dc_irq        ),
    .irq_cause_o  ( dc_irq_cause  ),
    .irq_ret_o    ( dc_irq_ret_o  )
  );

  // ------------
  // Output logic

  assign irq_ret_o = dc_irq_ret_o;
  assign irq_cause_o = dc_irq_cause;
  assign irq_o = dc_irq;

endmodule
