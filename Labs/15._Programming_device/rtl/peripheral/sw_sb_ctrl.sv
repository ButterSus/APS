module sw_sb_ctrl (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    input  logic        irq_ret_i,
    output logic        irq_req_o,

    input  logic [15:0] sw_i
);

  localparam bit [23:0] VALUE_ADDR = 24'h0;

  logic [15:0] sw;

  logic [15:0] sw_r;
  logic        sw_r_vld;

  wire irq_req_gen = sw_r_vld & (sw_r != sw);

  // ---------------------------
  // Buffer sw_i (async to sync)

  localparam int SHIFT_DEPTH = 4;

  logic [15:0] sw_sync;
  logic [SHIFT_DEPTH - 1:0][15:0] sw_shift_r;

  always_ff @ (posedge clk_i)
    sw_shift_r <= { sw_i, sw_shift_r [SHIFT_DEPTH - 1:1] };

  assign sw_sync = sw_shift_r [0];

  // ----------------
  // Debounce sw_sync

  custom_debouncer #(.WIDTH(16)) i_custom_debouncer
  (
    .clk_i  ( clk_i   ),
    .rst_i  ( rst_i   ),
    .data_i ( sw_sync ),
    .data_o ( sw      )
  );

  // ------------
  // Driver logic

  logic [15:0] sw_snapshot;
  logic irq_req_r;

  always_ff @ (posedge clk_i)
    if (rst_i)
      sw_snapshot <= 16'd0;
    else if (irq_req_gen &~ irq_req_r)
      sw_snapshot <= sw;

  // ----------------
  // Interrupts logic

  always_ff @ (posedge clk_i)
    sw_r <= sw;

  always_ff @ (posedge clk_i)
    if (rst_i)
      sw_r_vld <= 1'b0;
    else
      sw_r_vld <= 1'b1;

  always_ff @ (posedge clk_i)
    if (rst_i)
      irq_req_r <= 1'b0;
    else if (irq_req_gen &~ irq_req_r)
      irq_req_r <= 1'b1;
    else if (irq_ret_i & irq_req_r)
      irq_req_r <= 1'b0;

  // ------------
  // Output logic

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        VALUE_ADDR : read_data_o <= { 16'd0, sw_snapshot };
        default :;
      endcase

  assign irq_req_o = irq_req_gen | irq_req_r;

endmodule
