module processor_system (
    input logic clk_i,
    input logic rst_i
);

  // ----------------
  // Variable defines

  wire [31:0] im_read_data;

  wire        pc_mem_req;
  wire [31:0] pc_instr_addr;
  wire        pc_mem_req;
  wire        pc_mem_we;
  wire [ 2:0] pc_mem_size;
  wire [31:0] pc_mem_wd;
  wire [31:0] pc_mem_addr;

  wire [31:0] lsu_core_rd;
  wire        lsu_core_stall;
  wire        lsu_mem_req;
  wire        lsu_mem_we;
  wire [ 3:0] lsu_mem_be;
  wire [31:0] lsu_mem_addr;
  wire [31:0] lsu_mem_wd;

  wire [31:0] dm_read_data;
  wire        dm_ready;

  // ------------------------
  // Instruction memory logic

  instr_mem i_im
  (
    .read_addr_i ( pc_instr_addr ),
    .read_data_o ( im_read_data  )
  );

  // --------------------
  // Processor core logic

  processor_core /* i_pc */ core
  (
    .clk_i        ( clk_i          ),
    .rst_i        ( rst_i          ),
    .stall_i      ( lsu_core_stall ),
    .instr_i      ( im_read_data   ),
    .mem_rd_i     ( lsu_core_rd    ),
    .instr_addr_o ( pc_instr_addr  ),
    .mem_addr_o   ( pc_mem_addr    ),
    .mem_size_o   ( pc_mem_size    ),
    .mem_req_o    ( pc_mem_req     ),
    .mem_we_o     ( pc_mem_we      ),
    .mem_wd_o     ( pc_mem_wd      )
  );

  // ---------------
  // Load store unit

  lsu i_lsu
  (
    .clk_i        ( clk_i          ),
    .rst_i        ( rst_i          ),
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
    .mem_rd_i     ( dm_read_data   ),
    .mem_ready_i  ( dm_ready       )
  );

  // -----------------
  // Data memory logic

  data_mem i_dm
  (
    .clk_i          ( clk_i        ),
    .mem_req_i      ( lsu_mem_req  ),
    .write_enable_i ( lsu_mem_we   ),
    .byte_enable_i  ( lsu_mem_be   ),
    .addr_i         ( lsu_mem_addr ),
    .write_data_i   ( lsu_mem_wd   ),
    .read_data_o    ( dm_read_data ),
    .ready_o        ( dm_ready     )
  );

endmodule
