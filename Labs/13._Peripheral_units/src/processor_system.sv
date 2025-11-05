
module processor_system (
    input  logic        clk_i,
    input  logic        resetn_i,
    input  logic [15:0] sw_i,
    output logic [15:0] led_o,
    input  logic        kclk_i,
    input  logic        kdata_i,
    output logic [ 6:0] hex_led_o,
    output logic [ 7:0] hex_sel_o,
    input  logic        rx_i,
    output logic        tx_o,
    input  logic [ 3:0] vga_r_o,
    input  logic [ 3:0] vga_g_o,
    input  logic [ 3:0] vga_b_o,
    input  logic        vga_hs_o,
    input  logic        vga_vs_o
);

  wire uart_rx_i;
  assign uart_rx_i = rx_i;

  wire uart_tx_o;
  assign tx_o = uart_tx_o;

  // System clock
  // ------------

  logic sysclk, rst;

  sys_clk_rst_gen divider
  (
    .ex_clk_i      ( clk_i    ),
    .ex_areset_n_i ( resetn_i ),
    .div_i         ( 5        ),
    .sys_clk_o     ( sysclk   ),
    .sys_reset_o   ( rst      )
  );

  // ----------------
  // Variable defines

  wire  [31:0] imem_read_data;

  wire  [31:0] pc_instr_addr;
  wire         pc_mem_req;
  wire         pc_mem_we;
  wire  [ 2:0] pc_mem_size;
  wire  [31:0] pc_mem_wd;
  wire  [31:0] pc_mem_addr;

  wire  [31:0] lsu_core_rd;
  wire         lsu_core_stall;
  wire         lsu_mem_req;
  wire         lsu_mem_we;
  wire  [ 3:0] lsu_mem_be;
  wire  [31:0] lsu_mem_addr;
  logic [31:0] lsu_mem_wd;
  logic [31:0] lsu_mem_rd;
  logic        lsu_mem_ready;

  // ------------------------
  // Instruction memory logic

  instr_mem i_imem
  (
    .read_addr_i ( pc_instr_addr ),
    .read_data_o ( imem_read_data  )
  );

  // --------------------
  // Processor core logic

  logic [15:0] irq_req;
  wire  [15:0] irq_ret;

  processor_core core  // = i_pc
  (
    .clk_i        ( sysclk         ),
    .rst_i        ( rst            ),
    .stall_i      ( lsu_core_stall ),
    .instr_i      ( imem_read_data ),
    .mem_rd_i     ( lsu_core_rd    ),
    .irq_req_i    ( irq_req        ),
    .instr_addr_o ( pc_instr_addr  ),
    .mem_addr_o   ( pc_mem_addr    ),
    .mem_size_o   ( pc_mem_size    ),
    .mem_req_o    ( pc_mem_req     ),
    .mem_we_o     ( pc_mem_we      ),
    .mem_wd_o     ( pc_mem_wd      ),
    .irq_ret_o    ( irq_ret        )
  );

  // ---------------
  // Load store unit

  lsu i_lsu
  (
    .clk_i        ( sysclk         ),
    .rst_i        ( rst            ),
    .core_req_i   ( pc_mem_req     ),
    .core_we_i    ( pc_mem_we      ),
    .core_size_i  ( pc_mem_size    ),
    .core_addr_i  ( pc_mem_addr    ),
    .core_wd_i    ( pc_mem_wd      ),
    .core_rd_o    ( lsu_core_rd    ),
    .core_stall_o ( lsu_core_stall ),
    .mem_req_o    ( lsu_mem_req    ),
    .mem_we_o     ( lsu_mem_we     ),
    .mem_be_o     ( lsu_mem_be     ),
    .mem_addr_o   ( lsu_mem_addr   ),
    .mem_wd_o     ( lsu_mem_wd     ),
    .mem_rd_i     ( lsu_mem_rd     ),
    .mem_ready_i  ( lsu_mem_ready  )
  );

  // ================
  // System bus logic

  // "sb" stands for "system bus".

  import peripheral_pkg::*;

  logic dmem_req;
  logic sw_req;
  logic led_req;
  logic ps2_req;
  logic hex_req;
  logic uart_rx_req;
  logic uart_tx_req;
  logic vga_req;
  logic timer_req;

  always_comb begin
    dmem_req    = 1'b0;
    sw_req      = 1'b0;
    led_req     = 1'b0;
    ps2_req     = 1'b0;
    hex_req     = 1'b0;
    uart_rx_req = 1'b0;
    uart_tx_req = 1'b0;
    vga_req     = 1'b0;
    timer_req   = 1'b0;

    case (lsu_mem_addr [31:24])
      DMEM_ADDR_HIGH  : dmem_req    = lsu_mem_req;
      SW_ADDR_HIGH    : sw_req      = lsu_mem_req;
      LED_ADDR_HIGH   : led_req     = lsu_mem_req;
      PS2_ADDR_HIGH   : ps2_req     = lsu_mem_req;
      HEX_ADDR_HIGH   : hex_req     = lsu_mem_req;
      RX_ADDR_HIGH    : uart_rx_req = lsu_mem_req;
      TX_ADDR_HIGH    : uart_tx_req = lsu_mem_req;
      VGA_ADDR_HIGH   : vga_req     = lsu_mem_req;
      TIMER_ADDR_HIGH : timer_req   = lsu_mem_req;

      default :;
    endcase
  end

  wire [31:0] dmem_rd;
  wire [31:0] sw_rd;
  wire [31:0] led_rd;
  wire [31:0] ps2_rd;
  wire [31:0] hex_rd;
  wire [31:0] uart_rx_rd;
  wire [31:0] uart_tx_rd;
  wire [31:0] vga_rd;
  wire [31:0] timer_rd;

  wire dmem_ready;
  wire sw_ready      = 1'b1;
  wire led_ready     = 1'b1;
  wire ps2_ready     = 1'b1;
  wire hex_ready     = 1'b1;
  wire uart_rx_ready = 1'b1;
  wire uart_tx_ready = 1'b1;
  wire vga_ready     = 1'b1;
  wire timer_ready   = 1'b1;

  always_comb begin
    lsu_mem_rd    = 32'dx;
    lsu_mem_ready = 1'b0;

    case (lsu_mem_addr [31:24])
      DMEM_ADDR_HIGH  : lsu_mem_rd = dmem_rd;
      SW_ADDR_HIGH    : lsu_mem_rd = sw_rd;
      LED_ADDR_HIGH   : lsu_mem_rd = led_rd;
      PS2_ADDR_HIGH   : lsu_mem_rd = ps2_rd;
      HEX_ADDR_HIGH   : lsu_mem_rd = hex_rd;
      RX_ADDR_HIGH    : lsu_mem_rd = uart_rx_rd;
      TX_ADDR_HIGH    : lsu_mem_rd = uart_tx_rd;
      VGA_ADDR_HIGH   : lsu_mem_rd = vga_rd;
      TIMER_ADDR_HIGH : lsu_mem_rd = timer_rd;

      default :;
    endcase

    case (lsu_mem_addr [31:24])
      DMEM_ADDR_HIGH  : lsu_mem_ready = dmem_ready;
      SW_ADDR_HIGH    : lsu_mem_ready = sw_ready;
      LED_ADDR_HIGH   : lsu_mem_ready = led_ready;
      PS2_ADDR_HIGH   : lsu_mem_ready = ps2_ready;
      HEX_ADDR_HIGH   : lsu_mem_ready = hex_ready;
      RX_ADDR_HIGH    : lsu_mem_ready = uart_rx_ready;
      TX_ADDR_HIGH    : lsu_mem_ready = uart_tx_ready;
      VGA_ADDR_HIGH   : lsu_mem_ready = vga_ready;
      TIMER_ADDR_HIGH : lsu_mem_ready = timer_ready;

      default :;
    endcase
  end

  // ----------
  // Interrupts

  wire sw_irq_req, sw_irq_ret;
  wire uart_rx_irq_req, uart_rx_irq_ret;

  always_comb begin
    irq_req = 16'd0;
    irq_req [SW_INT_IDX]      = sw_irq_req;
    irq_req [UART_RX_INT_IDX] = uart_rx_irq_req;
  end

  assign sw_irq_ret = irq_ret [SW_INT_IDX];

  // -----------
  // Data memory

  data_mem i_dmem
  (
    .clk_i          ( sysclk       ),
    .mem_req_i      ( dmem_req     ),
    .write_enable_i ( lsu_mem_we   ),
    .byte_enable_i  ( lsu_mem_be   ),
    .addr_i         ( lsu_mem_addr ),
    .write_data_i   ( lsu_mem_wd   ),
    .read_data_o    ( dmem_rd      ),
    .ready_o        ( dmem_ready   )
  );

  // --------
  // Switches

  sw_sb_ctrl i_sw_ctrl
  (
    .clk_i          ( sysclk       ),
    .rst_i          ( rst          ),
    .req_i          ( sw_req       ),
    .write_enable_i ( lsu_mem_we   ),
    .addr_i         ( lsu_mem_addr ),
    .write_data_i   ( lsu_mem_wd   ),
    .read_data_o    ( sw_rd        ),
    .irq_req_o      ( sw_irq_req   ),
    .irq_ret_i      ( sw_irq_ret   ),
    .sw_i           ( sw_i         )
  );

  // ----
  // LEDs

  led_sb_ctrl i_led_ctrl
  (
    .clk_i          ( sysclk       ),
    .rst_i          ( rst          ),
    .req_i          ( led_req      ),
    .write_enable_i ( lsu_mem_we   ),
    .addr_i         ( lsu_mem_addr ),
    .write_data_i   ( lsu_mem_wd   ),
    .read_data_o    ( led_rd       ),
    .led_o          ( led_o        )
  );

  // -------------
  // Keyboard PS/2

  // ---------------------
  // Seven-segment display

  hex_sb_ctrl i_hex_ctrl
  (
    .clk_i          ( sysclk       ),
    .rst_i          ( rst          ),
    .req_i          ( hex_req      ),
    .write_enable_i ( lsu_mem_we   ),
    .addr_i         ( lsu_mem_addr ),
    .write_data_i   ( lsu_mem_wd   ),
    .read_data_o    ( hex_rd       ),
    .hex_led_o      ( hex_led_o    ),
    .hex_sel_o      ( hex_sel_o    )
  );

  // -------
  // UART RX

  uart_rx_sb_ctrl i_uart_rx_ctrl
  (
    .clk_i          ( sysclk          ),
    .rst_i          ( rst             ),
    .req_i          ( uart_rx_req     ),
    .write_enable_i ( lsu_mem_we      ),
    .addr_i         ( lsu_mem_addr    ),
    .write_data_i   ( lsu_mem_wd      ),
    .read_data_o    ( uart_rx_rd      ),
    .irq_req_o      ( uart_rx_irq_req ),
    .irq_ret_i      ( uart_rx_irq_ret ),
    .rx_i           ( uart_rx_i       )
  );

  // -------
  // UART TX

  // -----------
  // VGA-adapter

  // -----
  // Timer

endmodule
