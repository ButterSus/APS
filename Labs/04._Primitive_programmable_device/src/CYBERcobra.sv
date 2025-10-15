module CYBERcobra (
  input  logic         clk_i,
  input  logic         rst_i,
  input  logic [15:0]  sw_i,
  output logic [31:0]  out_o
);

  // Variables declarations

  wire jump;
  wire branch;

  wire [9:0] offset;  // words

  wire [4:0] reg1_addr;
  wire [4:0] reg2_addr;
  wire [4:0] dest_addr;

  wire [4:0] alu_op;

  wire [1:0] write_src;

  wire [22:0] imm;

  logic [31:0] pc_reg;

  wire [31:0] instr_bus;

  logic [31:0] rf_write_data;
  wire [31:0] rf_data1;
  wire [31:0] rf_data2;

  wire [31:0] alu_result;
  wire        alu_flag;

  // -------
  // Decoder

  assign jump   = instr_bus [31];
  assign branch = instr_bus [30];

  assign offset = { instr_bus [12:5], 2'd0 };

  assign reg1_addr = instr_bus [22:18];
  assign reg2_addr = instr_bus [17:13];
  assign dest_addr = instr_bus [ 4: 0];

  assign alu_op = instr_bus [27:23];

  assign write_src = instr_bus [29:28];

  assign imm = instr_bus [27:5];

  // ---------------
  // Program counter

  always_ff @ ( posedge clk_i )
    if (rst_i)
      pc_reg <= 32'd0;
    else
      pc_reg <= pc_reg + ((jump | branch & alu_flag) ? offset : 32'd4);

  // ------------------
  // Instruction memory

  instr_mem imem
  (
    .read_addr_i ( pc_reg    ),
    .read_data_o ( instr_bus )
  );

  // =============
  // Register File

  assign out_o = rf_data1;

  always_comb
    unique case (write_src)
      2'd0 : rf_write_data = { { 9 { imm [22] } }, imm };
      2'd1 : rf_write_data = alu_result;
      2'd2 : rf_write_data = { { 16 { sw_i [15] } }, sw_i };
      2'd3 : rf_write_data = 32'd0;
    endcase

  register_file i_rf
  (
    .clk_i          ( clk_i           ),
    .write_enable_i ( ~branch & ~jump ),
    .read_addr1_i   ( reg1_addr       ),
    .read_addr2_i   ( reg2_addr       ),
    .write_addr_i   ( dest_addr       ),
    .write_data_i   ( rf_write_data   ),
    .read_data1_o   ( rf_data1        ),
    .read_data2_o   ( rf_data2        )
  );

  // Arithmetic Logic Unit
  // ---------------------

  alu i_alu
  (
    .a_i      ( rf_data1   ),
    .b_i      ( rf_data2   ),
    .alu_op_i ( alu_op     ),
    .flag_o   ( alu_flag   ),
    .result_o ( alu_result )
  );

endmodule
