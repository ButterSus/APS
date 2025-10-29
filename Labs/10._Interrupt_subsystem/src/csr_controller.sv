module csr_controller (

    input logic clk_i,
    input logic rst_i,
    input logic trap_i,

    input logic [2:0] opcode_i,

    input logic [11:0] addr_i,
    input logic [31:0] pc_i,
    input logic [31:0] mcause_i,
    input logic [31:0] rs1_data_i,
    input logic [31:0] imm_data_i,
    input logic        write_enable_i,

    output logic [31:0] read_data_o,
    output logic [31:0] mie_o,
    output logic [31:0] mepc_o,
    output logic [31:0] mtvec_o
);

  import csr_pkg::*;

  // -------------------
  // Write data generate

  logic [31:0] write_data;

  always_comb
    case (opcode_i)
      CSR_RW  : write_data = rs1_data_i;
      CSR_RS  : write_data = read_data_o | rs1_data_i;
      CSR_RC  : write_data = read_data_o &~ rs1_data_i;
      CSR_RWI : write_data = imm_data_i;
      CSR_RSI : write_data = read_data_o | imm_data_i;
      CSR_RCI : write_data = read_data_o &~ imm_data_i;

      default : write_data = 32'dx;
    endcase

  // -------------
  // Register file

  // NOTE: Unfortunately, testbench doesn't
  // allow aggressive register optimizations.

  logic [31:0] mie_csr;
  // assign mie_csr   [15:0] = 16'd0;  // No software interrupts,
  // since we don't have multiple harts for now.
  logic [31:0] mtvec_csr;
  // assign mtvec_csr [ 1:0] = 2'b00;  // MODE = DIRECT
  logic [31:0] mscratch_csr;
  logic [31:0] mepc_csr;
  logic [31:0] mcause_csr;  // For simplicity, we won't cut it

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      // mie_csr   [31:16] <= 16'd0;
      mie_csr           <= 32'd0;
      // mtvec_csr [31: 2] <= 30'd0;
      mtvec_csr         <= 30'd0;
      mscratch_csr      <= 32'd0;
      mepc_csr          <= 32'd0;
      mcause_csr        <= 32'd0;
    end
    else if (trap_i) begin
      mepc_csr   <= pc_i;
      mcause_csr <= mcause_i;
    end
    else if (write_enable_i)
      case (addr_i)
        // MIE_ADDR      : mie_csr   [31:16] <= write_data [31:16];
        MIE_ADDR      : mie_csr           <= write_data;
        // MTVEC_ADDR    : mtvec_csr [31: 2] <= write_data [31: 2];
        MTVEC_ADDR    : mtvec_csr         <= write_data;
        MSCRATCH_ADDR : mscratch_csr      <= write_data;
        MEPC_ADDR     : mepc_csr          <= write_data;
        MCAUSE_ADDR   : mcause_csr        <= write_data;

        default :;
      endcase

  always_comb
    case (addr_i)
      MIE_ADDR      : read_data_o = mie_csr;
      MTVEC_ADDR    : read_data_o = mtvec_csr;
      MSCRATCH_ADDR : read_data_o = mscratch_csr;
      MEPC_ADDR     : read_data_o = mepc_csr;
      MCAUSE_ADDR   : read_data_o = mcause_csr;

      default : read_data_o = 32'dx;
    endcase

  // --------------------------------
  // Expose registers to output ports

  assign mie_o   = mie_csr;
  assign mepc_o  = mepc_csr;
  assign mtvec_o = mtvec_csr;

endmodule
