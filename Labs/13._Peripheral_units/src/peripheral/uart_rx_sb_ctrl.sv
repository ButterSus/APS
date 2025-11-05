module uart_rx_sb_ctrl (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    input  logic        irq_ret_i,
    output logic        irq_req_o,

    input logic         rx_i
);

  localparam bit [23:0] DATA_ADDR      = 24'h00;
  localparam bit [23:0] VALID_ADDR     = 24'h04;
  localparam bit [23:0] BUSY_ADDR      = 24'h08;
  localparam bit [23:0] BAUDRATE_ADDR  = 24'h0C;
  localparam bit [23:0] PARITY_EN_ADDR = 24'h10;
  localparam bit [23:0] STOPBIT_ADDR   = 24'h14;
  localparam bit [23:0] RESET_ADDR     = 24'h24;

  wire ext_rst = (req_i & write_enable_i) & (addr_i [23:0] == RESET_ADDR);
  wire read_done = (req_i &~ write_enable_i) & (addr_i [23:0] == DATA_ADDR) | irq_ret_i;

  // -----------
  // Input logic

  wire busy;

  logic [16:0] baudrate_r;
  logic        parity_en_r;
  logic [ 1:0] stopbit_r;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst) begin
      baudrate_r  <= 17'd9600;
      parity_en_r <= 1'b0;
      stopbit_r   <= 2'd1;
    end
    else if (req_i && write_enable_i)
      // Stream settings, immutable during receiving
      if (~busy)
        case (addr_i [23:0])
          BAUDRATE_ADDR  : baudrate_r  <= write_data_i [16:0];
          PARITY_EN_ADDR : parity_en_r <= write_data_i [0];
          STOPBIT_ADDR   : stopbit_r   <= write_data_i [1:0];
          default :;
        endcase

  // ---------------
  // Wrapping driver

  logic       /* busy, */ busy_r;
  logic [7:0] data, data_r;
  logic       valid, valid_r;

  uart_rx i_driver
  (
    .clk_i       ( clk_i           ),
    .rst_i       ( rst_i | ext_rst ),
    .busy_o      ( busy            ),
    .baudrate_i  ( baudrate_r      ),
    .parity_en_i ( parity_en_r     ),
    .stopbit_i   ( stopbit_r       ),
    .rx_data_o   ( data            ),
    .rx_valid_o  ( valid           ),
    .rx_i        ( rx_i            )
  );

  always_ff @ (posedge clk_i)
    busy_r <= busy;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst | read_done) begin
      valid_r <= 1'b0;
    end
    else if (valid) begin
      valid_r <= 1'b1;
      data_r  <= data;
    end

  // ------------
  // Output logic

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        DATA_ADDR      : read_data_o <= { 24'd0, data_r };
        BUSY_ADDR      : read_data_o <= { 31'd0, busy_r };
        BAUDRATE_ADDR  : read_data_o <= { 15'd0, baudrate_r };
        PARITY_EN_ADDR : read_data_o <= { 31'd0, parity_en_r };
        STOPBIT_ADDR   : read_data_o <= { 30'd0, stopbit_r };
        default :;
      endcase

  assign irq_req_o = valid_r;

endmodule
