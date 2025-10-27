module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        stall_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] mem_rd_i,

  output logic [31:0] instr_addr_o,
  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o
);

  // -----------------
  // Fields extraction

  wire [4:0] rs2;
  wire [4:0] rs1;
  wire [4:0] rd;

  assign rs2 = instr_i [24:20];
  assign rs1 = instr_i [19:15];
  assign rd  = instr_i [11: 7];

  // ---------------------
  // Immediates extraction

  wire [31:0] imm_I;
  wire [31:0] imm_U;
  wire [31:0] imm_S;
  wire [31:0] imm_B;
  wire [31:0] imm_J;

  assign imm_I [11: 0] = instr_i [31:20];
  assign imm_I [31:12] = { 20 { imm_I [11] } };

  assign imm_U [11: 0] = 12'd0;
  assign imm_U [31:12] = instr_i [31:12];

  assign imm_S [ 4: 0] = instr_i [11: 7];
  assign imm_S [11: 5] = instr_i [31:25];
  assign imm_S [31:12] = { 20 { imm_S [11] } };

  assign imm_B [    0] = 1'b0;
  assign imm_B [ 4: 1] = instr_i [11: 8];
  assign imm_B [10: 5] = instr_i [30:25];
  assign imm_B [   11] = instr_i [    7];
  assign imm_B [   12] = instr_i [   31];
  assign imm_B [31:13] = { 19 { imm_B [12] } };

  assign imm_J [    0] = 1'b0;
  assign imm_J [10: 1] = instr_i [30:21];
  assign imm_J [   11] = instr_i [   20];
  assign imm_J [19:12] = instr_i [19:12];
  assign imm_J [   20] = instr_i [   31];
  assign imm_J [31:21] = { 19 { imm_J [20] } };

  // ----------------
  // Variable defines

  wire [ 1:0] dcd_a_sel;
  wire [ 2:0] dcd_b_sel;
  wire [ 4:0] dcd_alu_op;
  wire [ 2:0] dcd_csr_op;
  wire        dcd_csr_we;
  wire        dcd_gpr_we;
  wire [ 1:0] dcd_wb_sel;
  wire        dcd_illegal_instr;
  wire        dcd_branch;
  wire        dcd_jal;
  wire        dcd_jalr;
  wire        dcd_mret;

  logic [31:0] pc_r, pc_next;

  // -------------
  // Decoder logic

  decoder i_dcd
  (
    .fetched_instr_i ( instr_i           ),
    .a_sel_o         ( dcd_a_sel         ),
    .b_sel_o         ( dcd_b_sel         ),
    .alu_op_o        ( dcd_alu_op        ),
    .csr_op_o        ( dcd_csr_op        ),
    .csr_we_o        ( dcd_csr_we        ),
    .mem_req_o       ( mem_req_o         ),
    .mem_we_o        ( mem_we_o          ),
    .mem_size_o      ( mem_size_o        ),
    .gpr_we_o        ( dcd_gpr_we        ),
    .wb_sel_o        ( dcd_wb_sel        ),
    .illegal_instr_o ( dcd_illegal_instr ),
    .branch_o        ( dcd_branch        ),
    .jal_o           ( dcd_jal           ),
    .jalr_o          ( dcd_jalr          ),
    .mret_o          ( dcd_mret          )
  );

  // -------------------
  // Register file logic

  wire rf_we;
  wire [31:0] rf_write_data;

  assign rf_we = dcd_gpr_we & ~ stall_i;
  assign rf_write_data = dcd_wb_sel ? mem_rd_i : alu_result;

  wire [31:0] rf_read_data1;
  wire [31:0] rf_read_data2;

  register_file i_rf
  (
    .clk_i          ( clk_i         ),
    .write_enable_i ( rf_we         ),
    .write_addr_i   ( rd            ),
    .read_addr1_i   ( rs1           ),
    .read_addr2_i   ( rs2           ),
    .write_data_i   ( rf_write_data ),
    .read_data1_o   ( rf_read_data1 ),
    .read_data2_o   ( rf_read_data2 )
  );

  // ---------------------
  // Arithmetic unit logic

  logic [31:0] alu_a;
  logic [31:0] alu_b;

  always_comb
    case (dcd_a_sel)
      2'd0 : alu_a = rf_read_data1;
      2'd1 : alu_a = pc_r;
      2'd2 : alu_a = 32'd0;

      default : alu_a = 32'dx;
    endcase

  always_comb
    case (dcd_b_sel)
      3'd0 : alu_b = rf_read_data2;
      3'd1 : alu_b = imm_I;
      3'd2 : alu_b = imm_U;
      3'd3 : alu_b = imm_S;
      3'd4 : alu_b = 32'd4;

      default : alu_b = 32'dx;
    endcase

  wire        alu_flag;
  wire [31:0] alu_result;

  alu i_alu
  (
    .a_i      ( alu_a      ),
    .b_i      ( alu_b      ),
    .alu_op_i ( dcd_alu_op ),
    .flag_o   ( alu_flag   ),
    .result_o ( alu_result )
  );

  // ---------------------
  // Program counter logic

  wire [31:0] pc_offset;

  assign pc_offset = (dcd_jal | dcd_branch & alu_flag)
                      ? (dcd_branch ? imm_B : imm_J)
                      : 32'd4;

  always_comb
    case (dcd_jalr)
      1'b0 : pc_next = pc_r + pc_offset;
      1'b1 : pc_next = rf_read_data1 + imm_I;

      default :;
    endcase

  always_ff @ (posedge clk_i)
    if (rst_i)
      pc_r <= 32'd0;
    else if (~ stall_i)
      pc_r <= pc_next;

  // ------------
  // Output logic

  assign instr_addr_o = pc_r;
  assign mem_addr_o   = alu_result;
  assign mem_wd_o     = rf_read_data2;

endmodule
