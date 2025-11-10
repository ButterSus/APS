module ps2_sb_ctrl (
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

  localparam bit [23:0] KEYCODE_ADDR = 24'h00;
  localparam bit [23:0] VALID_ADDR   = 24'h04;
  localparam bit [23:0] RESET_ADDR   = 24'h24;

  wire ext_rst   = (req_i & write_enable_i) & (addr_i [23:0] == RESET_ADDR);
  wire read_done = (req_i &~ write_enable_i) & (addr_i [23:0] == KEYCODE_ADDR) | irq_ret_i;

  // ---------------
  // Wrapping driver

  logic [7:0] keycode, keycode_r;
  logic       valid, valid_r;

  PS2Receiver i_driver
  (
    .clk_i           ( clk_i           ),
    .rst_i           ( rst_i | ext_rst ),
    .keycode_o       ( keycode         ),
    .keycode_valid_o ( valid           ),
    .kclk_i          ( kclk_i          ),
    .kdata_i         ( kdata_i         )
  );

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst | read_done &~ valid) begin
      valid_r <= 1'b0;
    end
    else if (valid) begin
      valid_r   <= 1'b1;
      keycode_r <= keycode;
    end

  // ------------
  // Output logic

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        KEYCODE_ADDR : read_data_o <= { 24'd0, keycode_r };
        VALID_ADDR   : read_data_o <= { 31'd0, valid_r };
        default :;
      endcase

  assign irq_req_o = valid_r;

endmodule
