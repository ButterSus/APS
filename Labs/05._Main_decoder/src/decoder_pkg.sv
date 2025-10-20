/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Andrei Solodovnikov
* Email(s)       : hepoh@org.miet.ru

See https://github.com/MPSU/APS/blob/master/LICENSE file for licensing details.
* ------------------------------------------------------------------------------
*/
package decoder_pkg;

  import alu_opcodes_pkg::*;
  import csr_pkg::*;

  // opcodes
  localparam LOAD_OPCODE     = 5'b00_000;
  localparam MISC_MEM_OPCODE = 5'b00_011;
  localparam OP_IMM_OPCODE   = 5'b00_100;
  localparam AUIPC_OPCODE    = 5'b00_101;
  localparam STORE_OPCODE    = 5'b01_000;
  localparam OP_OPCODE       = 5'b01_100;
  localparam LUI_OPCODE      = 5'b01_101;
  localparam BRANCH_OPCODE   = 5'b11_000;
  localparam JALR_OPCODE     = 5'b11_001;
  localparam JAL_OPCODE      = 5'b11_011;
  localparam SYSTEM_OPCODE   = 5'b11_100;

  // operand a selection
  localparam OP_A_RS1        = 2'b00;
  localparam OP_A_CURR_PC    = 2'b01;
  localparam OP_A_ZERO       = 2'b10;

  // operand b selection
  localparam OP_B_RS2        = 3'b000;
  localparam OP_B_IMM_I      = 3'b001;
  localparam OP_B_IMM_U      = 3'b010;
  localparam OP_B_IMM_S      = 3'b011;
  localparam OP_B_INCR       = 3'b100;

  // writeback source selection
  localparam WB_EX_RESULT    = 2'd0;
  localparam WB_LSU_DATA     = 2'd1;
  localparam WB_CSR_DATA     = 2'd2;

  // funct7 : OP
  localparam F7_ANY  = 7'b???????;
  localparam F7_SLLI = 7'b0000000;
  localparam F7_SRLI = 7'b0000000;
  localparam F7_SRAI = 7'b0100000;
  localparam F7_ADD  = 7'b0000000;
  localparam F7_SUB  = 7'b0100000;
  localparam F7_SLL  = 7'b0000000;
  localparam F7_SLT  = 7'b0000000;
  localparam F7_SLTU = 7'b0000000;
  localparam F7_XOR  = 7'b0000000;
  localparam F7_SRL  = 7'b0000000;
  localparam F7_SRA  = 7'b0100000;
  localparam F7_OR   = 7'b0000000;
  localparam F7_AND  = 7'b0000000;

  // funct3 : OP
  localparam F3_SLLI = 3'b001;
  localparam F3_SRLI = 3'b101;
  localparam F3_SRAI = 3'b101;
  localparam F3_ADD  = 3'b000;
  localparam F3_SUB  = 3'b000;
  localparam F3_SLL  = 3'b001;
  localparam F3_SLT  = 3'b010;
  localparam F3_SLTU = 3'b011;
  localparam F3_XOR  = 3'b100;
  localparam F3_SRL  = 3'b101;
  localparam F3_SRA  = 3'b101;
  localparam F3_OR   = 3'b110;
  localparam F3_AND  = 3'b111;

  // funct3 : OP_IMM
  localparam F3_ADDI  = 3'b000;
  localparam F3_SLTI  = 3'b010;
  localparam F3_SLTIU = 3'b011;
  localparam F3_XORI  = 3'b100;
  localparam F3_ORI   = 3'b110;
  localparam F3_ANDI  = 3'b111;

  // dmem type load store
  // (aka. funct3 : LOAD & STORE)
  localparam LDST_B  = 3'b000;
  localparam LDST_H  = 3'b001;
  localparam LDST_W  = 3'b010;
  localparam LDST_BU = 3'b100;
  localparam LDST_HU = 3'b101;

  // funct3 : BRANCH
  localparam F3_BEQ  = 3'b000;
  localparam F3_BNE  = 3'b001;
  localparam F3_BLT  = 3'b100;
  localparam F3_BGE  = 3'b101;
  localparam F3_BLTU = 3'b110;
  localparam F3_BGEU = 3'b111;

  // funct3 : JALR
  localparam F3_JALR = 3'b000;

  // funct3 : MISC_MEM
  localparam F3_FENCE = 3'b000;

  // Fixed word instructions
  localparam ECALL  = { 12'd0, 5'd0, 3'd0, 5'd0, SYSTEM_OPCODE, 2'b11 };
  localparam EBREAK = { 12'd1, 5'd0, 3'd0, 5'd0, SYSTEM_OPCODE, 2'b11 };
  localparam MRET   = { 7'b0011000, 5'b00010, 5'd0, 3'd0, 5'd0, SYSTEM_OPCODE, 2'b11 };

  /*
    Hack that makes nested opcodes be
    visible with just one import of
    decoder_pkg
  */

  export alu_opcodes_pkg::ALU_OP_WIDTH;
  export alu_opcodes_pkg::ALU_ADD;
  export alu_opcodes_pkg::ALU_SUB;
  export alu_opcodes_pkg::ALU_XOR;
  export alu_opcodes_pkg::ALU_OR;
  export alu_opcodes_pkg::ALU_AND;
  export alu_opcodes_pkg::ALU_SRA;
  export alu_opcodes_pkg::ALU_SRL;
  export alu_opcodes_pkg::ALU_SLL;
  export alu_opcodes_pkg::ALU_LTS;
  export alu_opcodes_pkg::ALU_LTU;
  export alu_opcodes_pkg::ALU_GES;
  export alu_opcodes_pkg::ALU_GEU;
  export alu_opcodes_pkg::ALU_EQ;
  export alu_opcodes_pkg::ALU_NE;
  export alu_opcodes_pkg::ALU_SLTS;
  export alu_opcodes_pkg::ALU_SLTU;

  export csr_pkg::CSR_RW;
  export csr_pkg::CSR_RS;
  export csr_pkg::CSR_RC;
  export csr_pkg::CSR_RWI;
  export csr_pkg::CSR_RSI;
  export csr_pkg::CSR_RCI;
  export csr_pkg::MIE_ADDR;
  export csr_pkg::MTVEC_ADDR;
  export csr_pkg::MSCRATCH_ADDR;
  export csr_pkg::MEPC_ADDR;
  export csr_pkg::MCAUSE_ADDR;

endpackage
