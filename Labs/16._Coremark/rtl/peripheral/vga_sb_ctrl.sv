module vga_sb_ctrl (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [3:0]  mem_be_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    input  logic        clk100m_i,
    output logic [ 3:0] vga_r_o,
    output logic [ 3:0] vga_g_o,
    output logic [ 3:0] vga_b_o,
    output logic        vga_hs_o,
    output logic        vga_vs_o
);

  // ---------------
  // Wrapping driver

  logic char_map_req;
  logic char_map_we;
  wire [31:0] char_map_rdata;

  logic col_map_req;
  logic col_map_we;
  wire [31:0] col_map_rdata;

  logic char_tiff_req;
  logic char_tiff_we;
  wire [31:0] char_tiff_rdata;

  vgachargen i_driver
  (
    .clk_i             ( clk_i           ),
    .clk100m_i         ( clk100m_i       ),
    .rst_i             ( rst_i           ),

    .char_map_req_i    ( char_map_req    ),
    .char_map_addr_i   ( addr_i [11:2]   ),
    .char_map_we_i     ( char_map_we     ),
    .char_map_be_i     ( mem_be_i        ),
    .char_map_wdata_i  ( write_data_i    ),
    .char_map_rdata_o  ( char_map_rdata  ),

    .col_map_req_i     ( col_map_req     ),
    .col_map_addr_i    ( addr_i [11:2]   ),
    .col_map_we_i      ( col_map_we      ),
    .col_map_be_i      ( mem_be_i        ),
    .col_map_wdata_i   ( write_data_i    ),
    .col_map_rdata_o   ( col_map_rdata   ),

    .char_tiff_req_i   ( char_tiff_req   ),
    .char_tiff_addr_i  ( addr_i [11:2]   ),
    .char_tiff_we_i    ( char_tiff_we    ),
    .char_tiff_be_i    ( mem_be_i        ),
    .char_tiff_wdata_i ( write_data_i    ),
    .char_tiff_rdata_o ( char_tiff_rdata ),

    .vga_r_o           ( vga_r_o         ),
    .vga_g_o           ( vga_g_o         ),
    .vga_b_o           ( vga_b_o         ),
    .vga_hs_o          ( vga_hs_o        ),
    .vga_vs_o          ( vga_vs_o        )
  );

  always_comb begin
    char_map_req  = 1'b0;
    char_map_we   = 1'b0;

    col_map_req   = 1'b0;
    col_map_we    = 1'b0;

    char_tiff_req = 1'b0;
    char_tiff_we  = 1'b0;

    case (addr_i [13:12])
      2'b00 : begin
        char_map_req  = req_i;
        char_map_we   = write_enable_i;
      end

      2'b01 : begin
        col_map_req   = req_i;
        col_map_we    = write_enable_i;
      end

      2'b10 : begin
        char_tiff_req = req_i;
        char_tiff_we  = write_enable_i;
      end

      default :;
    endcase
  end

  // ------------
  // Output logic

  always_comb
    case (addr_i [13:12])
      2'b00 : read_data_o = char_map_rdata;
      2'b01 : read_data_o = col_map_rdata;
      2'b10 : read_data_o = char_tiff_rdata;

      default : read_data_o = 32'dx;
    endcase

endmodule
