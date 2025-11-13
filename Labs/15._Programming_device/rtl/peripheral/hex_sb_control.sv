module hex_sb_ctrl (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    output logic [ 6:0] hex_led_o,
    output logic [ 7:0] hex_sel_o
);

  localparam bit [23:0] HEX0_ADDR    = 24'h00;
  localparam bit [23:0] HEX1_ADDR    = 24'h04;
  localparam bit [23:0] HEX2_ADDR    = 24'h08;
  localparam bit [23:0] HEX3_ADDR    = 24'h0C;
  localparam bit [23:0] HEX4_ADDR    = 24'h10;
  localparam bit [23:0] HEX5_ADDR    = 24'h14;
  localparam bit [23:0] HEX6_ADDR    = 24'h18;
  localparam bit [23:0] HEX7_ADDR    = 24'h1C;
  localparam bit [23:0] BITMASK_ADDR = 24'h20;
  localparam bit [23:0] RESET_ADDR   = 24'h24;

  wire ext_rst = (req_i & write_enable_i) & (addr_i [23:0] == RESET_ADDR);

  // -------------
  // Register file

  logic [3:0] hex0_r, hex1_r, hex2_r, hex3_r,
              hex4_r, hex5_r, hex6_r, hex7_r;

  logic [7:0] bitmask_r;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst) begin
      hex0_r    <= 4'd0;
      hex1_r    <= 4'd0;
      hex2_r    <= 4'd0;
      hex3_r    <= 4'd0;
      hex4_r    <= 4'd0;
      hex5_r    <= 4'd0;
      hex6_r    <= 4'd0;
      hex7_r    <= 4'd0;
      bitmask_r <= 8'hFF;
    end
    else if (req_i & write_enable_i)
      case (addr_i [23:0])
        HEX0_ADDR    : hex0_r    <= write_data_i [3:0];
        HEX1_ADDR    : hex1_r    <= write_data_i [3:0];
        HEX2_ADDR    : hex2_r    <= write_data_i [3:0];
        HEX3_ADDR    : hex3_r    <= write_data_i [3:0];
        HEX4_ADDR    : hex4_r    <= write_data_i [3:0];
        HEX5_ADDR    : hex5_r    <= write_data_i [3:0];
        HEX6_ADDR    : hex6_r    <= write_data_i [3:0];
        HEX7_ADDR    : hex7_r    <= write_data_i [3:0];
        BITMASK_ADDR : bitmask_r <= write_data_i [7:0];
        default :;
      endcase

  // ---------------
  // Wrapping driver

  hex_digits i_driver
  (
    .clk_i     ( clk_i           ),
    .rst_i     ( rst_i | ext_rst ),
    .hex0_i    ( hex0_r          ),
    .hex1_i    ( hex1_r          ),
    .hex2_i    ( hex2_r          ),
    .hex3_i    ( hex3_r          ),
    .hex4_i    ( hex4_r          ),
    .hex5_i    ( hex5_r          ),
    .hex6_i    ( hex6_r          ),
    .hex7_i    ( hex7_r          ),
    .bitmask_i ( bitmask_r       ),
    .hex_led_o ( hex_led_o       ),
    .hex_sel_o ( hex_sel_o       )
  );

  // ------------
  // Output logic

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        HEX0_ADDR    : read_data_o <= { 28'd0, hex0_r };
        HEX1_ADDR    : read_data_o <= { 28'd0, hex1_r };
        HEX2_ADDR    : read_data_o <= { 28'd0, hex2_r };
        HEX3_ADDR    : read_data_o <= { 28'd0, hex3_r };
        HEX4_ADDR    : read_data_o <= { 28'd0, hex4_r };
        HEX5_ADDR    : read_data_o <= { 28'd0, hex5_r };
        HEX6_ADDR    : read_data_o <= { 28'd0, hex6_r };
        HEX7_ADDR    : read_data_o <= { 28'd0, hex7_r };
        BITMASK_ADDR : read_data_o <= { 24'd0, bitmask_r };
        default :;
      endcase

endmodule
