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

  logic stall_r, stall_next;

  wire [31:0] dm_read_data;
  wire        dm_ready;

  // -----------
  // Stall logic

  assign stall_next = ~ stall_r & pc_mem_req;

  always_ff @ ( posedge clk_i )
    if (rst_i)
      stall_r <= 1'b0;
    else
      stall_r <= stall_next;

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
    .clk_i        ( clk_i         ),
    .rst_i        ( rst_i         ),
    .stall_i      ( stall_next    ),
    .instr_i      ( im_read_data  ),
    .mem_rd_i     ( dm_read_data  ),
    .instr_addr_o ( pc_instr_addr ),
    .mem_addr_o   ( pc_mem_addr   ),
    .mem_size_o   ( pc_mem_size   ),
    .mem_req_o    ( pc_mem_req    ),
    .mem_we_o     ( pc_mem_we     ),
    .mem_wd_o     ( pc_mem_wd     )
  );

  // -----------------
  // Data memory logic

  data_mem i_dm
  (
    .clk_i          ( clk_i        ),
    .mem_req_i      ( pc_mem_req   ),
    .write_enable_i ( pc_mem_we    ),
    .byte_enable_i  ( 4'b1111      ),
    .addr_i         ( pc_mem_addr  ),
    .write_data_i   ( pc_mem_wd    ),
    .read_data_o    ( dm_read_data ),
    .ready_o        ( dm_ready     )
  );

endmodule
