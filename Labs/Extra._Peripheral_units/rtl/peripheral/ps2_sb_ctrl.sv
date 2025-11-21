module ps2_sb_ctrl #(
    parameter int TIMEOUT_CYCLES = 10_000_000 / 2,  // 500 ms to start repeating
    parameter int REPEAT_CYCLES  = 10_000_000 / 10  // 10 interrupts per second holding key
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    input  logic        irq_ret_i,
    output logic        irq_req_o,

    input  logic        kclk_i,
    input  logic        kdata_i
);

  initial begin
    if (!(TIMEOUT_CYCLES >= REPEAT_CYCLES)) begin
      $error("TIMEOUT_CYCLES (%0d) must be >= REPEAT_CYCLES (%0d)", TIMEOUT_CYCLES, REPEAT_CYCLES);
    end
  end

  localparam bit [23:0] KEYCODE_ADDR = 24'h00;
  localparam bit [23:0] VALID_ADDR   = 24'h04;
  localparam bit [23:0] RESET_ADDR   = 24'h24;

  wire ext_rst   = (req_i & write_enable_i) & (addr_i [23:0] == RESET_ADDR);
  wire read_done = /* (req_i &~ write_enable_i) & (addr_i [23:0] == KEYCODE_ADDR) |  */irq_ret_i;

  // Wrapping driver
  // ---------------

  logic tag_hit;  // Avoid synthesizer warning

  // "*_out" registers are exposed to system bus

  logic [7:0] keycode, keycode_r, keycode_out, keycode_next;
  logic       driver_valid;
  logic       valid, valid_r, valid_out, valid_next;

  PS2Receiver i_driver
  (
    .clk_i           ( clk_i           ),
    .rst_i           ( rst_i | ext_rst ),
    .keycode_o       ( keycode         ),
    .keycode_valid_o ( driver_valid    ),
    .kclk_i          ( kclk_i          ),
    .kdata_i         ( kdata_i         )
  );

  // Here we also want to reduce critical path, since
  // anyway associative_memory takes 1 cycle to complete

  // Filter initial signal and make sure two consecutive valid keycodes
  // won't break controller
  assign valid = driver_valid &~ (keycode == 8'hAA) &~ valid_r;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst) begin
      valid_r <= 1'b0;
    end
    else begin
      keycode_r <= keycode;
      valid_r   <= valid;
    end

  logic release_state, release_state_r;

  assign release_state = (keycode_r == 8'hF0);
  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst)
      release_state_r <= 1'b0;
    else if (valid_r)
      release_state_r <= release_state;

  logic key_press, key_release;

  always_comb begin
    key_press   = valid_r &~ release_state_r &~ tag_hit &~ release_state;
    key_release = valid_r &  release_state_r &~ release_state;
  end

  // // We need to use CAM: Content Addressable Memory

  // There is no way to implement "true" hardware associative memory,
  // like there is no "systemverilog code for fully associative cache",
  // since this likely requires separate physical circuit design.

  // And since there are only 10 keys, let synthesizer do any complex
  // RTL schema under the hood, we don't care as long as it's small.

  logic [31:0] counter;
  logic empty;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst | empty)
      counter <= 32'd0;
    else if (~valid & ~valid_next & ~valid_out & (counter >= TIMEOUT_CYCLES))
      counter <= TIMEOUT_CYCLES - REPEAT_CYCLES;
    else if (~valid & ~valid_next & ~valid_out)
      counter <= counter + 1;

  logic [3:0] addr;
  logic addr_vld, addr_vld_r;
  logic addr_hit;
  logic [7:0] amem_keycode_i, amem_keycode_o;
  logic push, pop;

  always_comb begin
    addr     = 4'dx;
    addr_vld = 1'b0;

    if (~valid & ~valid_next & ~valid_out & (counter >= TIMEOUT_CYCLES - 10 + 1)) begin
      addr     = 4'(counter - (TIMEOUT_CYCLES - 10) - 1);
      addr_vld = 1'b1;
    end
  end

  always_ff @ (posedge clk_i)
    if (rst_i)
      addr_vld_r <= 1'b0;
    else
      addr_vld_r <= addr_vld;

  assign push = key_press;
  assign pop  = key_release;

  always_comb begin
    amem_keycode_i = keycode;

    if (valid_r)
      amem_keycode_i = keycode_r;
  end

  associative_memory #(.WIDTH(8), .DEPTH(10)) i_amem
  (
      .clk_i      ( clk_i          ),
      .rst_i      ( rst_i          ),

      .addr_i     ( addr           ),
      .addr_hit_o ( addr_hit       ),
      .tag_o      ( amem_keycode_o ),

      .tag_i      ( amem_keycode_i ),
      .push_i     ( push           ),
      .pop_i      ( pop            ),
      .tag_hit_o  ( tag_hit        ),

      .empty_o    ( empty          )
  );

  always_comb begin
    valid_next = 1'b0;

    // Theoretically impossible for both to be true at the same time
    if (key_press) begin
      valid_next   = 1'b1;
      keycode_next = keycode_r;
    end

    if (addr_vld_r & addr_hit) begin
      valid_next   = 1'b1;
      keycode_next = amem_keycode_o;
    end
  end

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst | read_done &~ (key_press | addr_vld_r)) begin
      valid_out <= 1'b0;
    end
    else if (key_press | addr_vld_r & addr_hit) begin
      valid_out   <= valid_next;
      keycode_out <= keycode_next;
    end


  // Output logic
  // ------------

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        KEYCODE_ADDR : read_data_o <= { 24'd0, keycode_out };
        VALID_ADDR   : read_data_o <= { 31'd0, valid_out };
        default :;
      endcase

  assign irq_req_o = valid_out;

endmodule
