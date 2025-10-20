module decoder (
    input  logic [31:0] fetched_instr_i,
    output logic [ 1:0] a_sel_o,
    output logic [ 2:0] b_sel_o,
    output logic [ 4:0] alu_op_o,
    output logic [ 2:0] csr_op_o,
    output logic        csr_we_o,
    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [ 2:0] mem_size_o,
    output logic        gpr_we_o,
    output logic [ 1:0] wb_sel_o,
    output logic        illegal_instr_o,
    output logic        branch_o,
    output logic        jal_o,
    output logic        jalr_o,
    output logic        mret_o
);

  import decoder_pkg::*;

  // --------------
  // General fields

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = fetched_instr_i [ 6: 0];
  assign funct3 = fetched_instr_i [14:12];
  assign funct7 = fetched_instr_i [31:25];

  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;

  assign rd  = fetched_instr_i [11: 7];
  assign rs1 = fetched_instr_i [19:15];
  assign rs2 = fetched_instr_i [24:20];

  logic [4:0] uimm;

  assign uimm = fetched_instr_i [19:15];

  // -------------------
  // Opcode verification

  logic illegal_opcode;

  always_comb begin
    illegal_opcode = 1'b1;

    if (opcode [1:0] == 2'b11)
      case (opcode[6:2])
        OP_OPCODE,
        OP_IMM_OPCODE,
        LUI_OPCODE,
        LOAD_OPCODE,
        STORE_OPCODE,
        BRANCH_OPCODE,
        JAL_OPCODE,
        JALR_OPCODE,
        AUIPC_OPCODE,
        MISC_MEM_OPCODE,
        SYSTEM_OPCODE : illegal_opcode = 1'b0;

        default :;
      endcase
  end

  // ----------------------
  // Map ALU argument muxes

  always_comb begin
    a_sel_o = /* 2'dx */ 2'd0;
    b_sel_o = /* 3'dx */ 3'd0;

    if (opcode [1:0] == 2'b11)
      case (opcode [6:2])
        // R-type
        OP_OPCODE : begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_RS2;
        end

        // I-type
        OP_IMM_OPCODE,
        LOAD_OPCODE : begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_IMM_I;
        end

        JALR_OPCODE : begin
          a_sel_o = OP_A_CURR_PC;
          b_sel_o = OP_B_INCR;
        end

        // S-type
        STORE_OPCODE : begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_IMM_S;
        end

        // B-type
        BRANCH_OPCODE : begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_RS2;
        end

        // U-type
        LUI_OPCODE : begin
          a_sel_o = OP_A_ZERO;
          b_sel_o = OP_B_IMM_U;
        end

        AUIPC_OPCODE : begin
          a_sel_o = OP_A_CURR_PC;
          b_sel_o = OP_B_IMM_U;
        end

        // J-type
        JAL_OPCODE : begin
          a_sel_o = OP_A_CURR_PC;
          b_sel_o = OP_B_INCR;
        end

        default :;
      endcase
  end

  // ------------------
  // Map ALU operations

  logic illegal_funct7_3_alu;

  always_comb begin
    illegal_funct7_3_alu = 1'b0;
    alu_op_o = /* 5'dx */ 5'd0;

    // By opcodes

    if (opcode == { OP_OPCODE, 2'b11 })
      case ({ funct7, funct3 })
        { F7_ADD , F3_ADD  } : alu_op_o = ALU_ADD ;
        { F7_SUB , F3_SUB  } : alu_op_o = ALU_SUB ;
        { F7_SLL , F3_SLL  } : alu_op_o = ALU_SLL ;
        { F7_SLT , F3_SLT  } : alu_op_o = ALU_SLTS;
        { F7_SLTU, F3_SLTU } : alu_op_o = ALU_SLTU;
        { F7_XOR , F3_XOR  } : alu_op_o = ALU_XOR ;
        { F7_SRL , F3_SRL  } : alu_op_o = ALU_SRL ;
        { F7_SRA , F3_SRA  } : alu_op_o = ALU_SRA ;
        { F7_OR  , F3_OR   } : alu_op_o = ALU_OR  ;
        { F7_AND , F3_AND  } : alu_op_o = ALU_AND ;

        default : illegal_funct7_3_alu = 1'b1;
      endcase

    if (opcode == { OP_IMM_OPCODE, 2'b11 })
      casez ({ funct7, funct3 })
        { F7_SLLI, F3_SLLI  } : alu_op_o = ALU_SLL ;
        { F7_SRLI, F3_SRLI  } : alu_op_o = ALU_SRL ;
        { F7_SRAI, F3_SRAI  } : alu_op_o = ALU_SRA ;
        { F7_ANY , F3_ADDI  } : alu_op_o = ALU_ADD ;
        { F7_ANY , F3_SLTI  } : alu_op_o = ALU_SLTS;
        { F7_ANY , F3_SLTIU } : alu_op_o = ALU_SLTU;
        { F7_ANY , F3_XORI  } : alu_op_o = ALU_XOR ;
        { F7_ANY , F3_ORI   } : alu_op_o = ALU_OR  ;
        { F7_ANY , F3_ANDI  } : alu_op_o = ALU_AND ;

        default : illegal_funct7_3_alu = 1'b1;
      endcase

    if (opcode == { LUI_OPCODE, 2'b11 })
      alu_op_o = ALU_ADD;

    if (opcode == { LOAD_OPCODE , 2'b11 } ||
        opcode == { STORE_OPCODE, 2'b11 })
      case (funct3)
        LDST_B,
        LDST_H,
        LDST_W,
        LDST_BU,
        LDST_HU : alu_op_o = ALU_ADD;

        default :;
      endcase

    if (opcode == { BRANCH_OPCODE, 2'b11 })
      case (funct3)
        F3_BEQ  : alu_op_o = ALU_EQ;
        F3_BNE  : alu_op_o = ALU_NE;
        F3_BLT  : alu_op_o = ALU_LTS;
        F3_BGE  : alu_op_o = ALU_GES;
        F3_BLTU : alu_op_o = ALU_LTU;
        F3_BGEU : alu_op_o = ALU_GEU;

        default : illegal_funct7_3_alu = 1'b1;
      endcase

    if (opcode == { JAL_OPCODE   , 2'b11 } ||
        opcode == { JALR_OPCODE  , 2'b11 } ||
        opcode == { AUIPC_OPCODE , 2'b11 } ||
        opcode == { SYSTEM_OPCODE, 2'b11 })
      alu_op_o = ALU_ADD;
  end

  // ---------------
  // Map RF controls

  always_comb begin
    gpr_we_o = 1'b0;
    wb_sel_o = /* 2'dx */ 2'd0;

    if (opcode [1:0] == 2'b11)
      case (opcode [6:2])
        OP_OPCODE,
        OP_IMM_OPCODE,
        LUI_OPCODE : begin
          gpr_we_o = !(illegal_funct7_3_alu);
          wb_sel_o = WB_EX_RESULT;
        end

        LOAD_OPCODE : begin
          gpr_we_o = !(illegal_funct3_mem);
          wb_sel_o = WB_LSU_DATA;
        end

        JAL_OPCODE,
        JALR_OPCODE,
        AUIPC_OPCODE : begin
          gpr_we_o = !(illegal_funct3_pc);
          wb_sel_o = WB_EX_RESULT;
        end

        SYSTEM_OPCODE :
          case (funct3)
            CSR_RW,
            CSR_RWI,
            CSR_RS,
            CSR_RC,
            CSR_RSI,
            CSR_RCI : begin
              gpr_we_o = /* (rd != 0) */ 1'b1;
              wb_sel_o = WB_CSR_DATA;
            end

            default :;
          endcase

        default :;
      endcase
  end

  // ----------------------
  // Map CSR & INT controls

  logic illegal_funct3_csr_int;
  logic illegal_raise;

  always_comb begin
    illegal_funct3_csr_int = 1'b0;
    illegal_raise          = 1'b0;
    csr_we_o = 1'b0;
    csr_op_o = /* 5'dx */ 5'd0;
    mret_o   = 1'b0;

    if (opcode == { SYSTEM_OPCODE, 2'b11 })
      case (funct3)
        CSR_RW,
        CSR_RWI : begin
          csr_we_o = 1'b1;
          csr_op_o = funct3;
        end

        // "uimm" is equivalent of "rs1"
        CSR_RS,
        CSR_RC : begin
          csr_we_o = /* (rs1 != 0) */ 1'b1;
          csr_op_o = funct3;
        end

        // "rs1" is equivalent of "uimm"
        CSR_RSI,
        CSR_RCI : begin
          csr_we_o = /* (uimm != 0) */ 1'b1;
          csr_op_o = funct3;
        end

        default :
          case (fetched_instr_i)
            ECALL,
            EBREAK : illegal_raise = 1'b1;
            MRET   : mret_o = 1'b1;

            default : illegal_funct3_csr_int = 1'b1;
          endcase
      endcase
  end

  // -------------------
  // Map memory controls

  logic illegal_funct3_mem;

  always_comb begin
    illegal_funct3_mem = 1'b0;
    mem_req_o  = 1'b0;
    mem_we_o   = 1'b0;
    mem_size_o = /* 3'dx */ 3'd0;

    if (opcode == { LOAD_OPCODE , 2'b11 })
      case (funct3)
        LDST_B,
        LDST_H,
        LDST_W,
        LDST_BU,
        LDST_HU : begin
          mem_req_o  = 1'b1;
          mem_size_o = funct3;
        end

        default : illegal_funct3_mem = 1'b1;
      endcase

    if (opcode == { STORE_OPCODE , 2'b11 })
      case (funct3)
        LDST_B,
        LDST_H,
        LDST_W : begin
          mem_req_o  = 1'b1;
          mem_we_o   = 1'b1;
          mem_size_o = funct3;
        end

        default : illegal_funct3_mem = 1'b1;
      endcase

    if (opcode == { MISC_MEM_OPCODE, 2'b11 })
      case (funct3)
        F3_FENCE : /* nop */;

        default : illegal_funct3_mem = 1'b1;
      endcase
  end

  // ------------------------
  // Program counter controls

  logic illegal_funct3_pc;

  always_comb begin
    illegal_funct3_pc = 1'b0;
    branch_o = 1'b0;
    jal_o    = 1'b0;
    jalr_o   = 1'b0;

    if (opcode [1:0] == 2'b11)
      case (opcode [6:2])
        BRANCH_OPCODE : branch_o = !(illegal_funct7_3_alu);
        JAL_OPCODE    : jal_o    = 1'b1;
        JALR_OPCODE   :
          case (funct3)
            F3_JALR : jalr_o = 1'b1;

            default : illegal_funct3_pc = 1'b1;
          endcase

        default :;
      endcase
  end

  // -------------------------
  // Illegal instruction logic

  assign illegal_instr_o = | {
    illegal_opcode,
    illegal_funct7_3_alu,
    illegal_funct3_csr_int,
    illegal_raise,
    illegal_funct3_mem,
    illegal_funct3_pc
  };

endmodule
