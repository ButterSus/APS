module lsu (
    input logic clk_i,
    input logic rst_i,

    // Интерфейс с ядром
    input  logic        core_req_i,
    input  logic        core_we_i,
    input  logic [ 2:0] core_size_i,
    input  logic [31:0] core_addr_i,
    input  logic [31:0] core_wd_i,
    output logic [31:0] core_rd_o,
    output logic        core_stall_o,

    // Интерфейс с памятью
    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [ 3:0] mem_be_o,
    output logic [31:0] mem_addr_o,
    output logic [31:0] mem_wd_o,
    input  logic [31:0] mem_rd_i,
    input  logic        mem_ready_i
);

  import decoder_pkg::*;

  // ---------------------
  // Drive general signals

  assign mem_req_o  = core_req_i;
  assign mem_we_o   = core_we_i;
  assign mem_addr_o = core_addr_i;

  // -------------------
  // Drive write signals

  always_comb begin
    mem_wd_o = 32'dx;

    case (core_size_i)
      LDST_B: mem_wd_o = {4{core_wd_i[7:0]}};
      LDST_H: mem_wd_o = {2{core_wd_i[15:0]}};
      LDST_W: mem_wd_o = {1{core_wd_i[31:0]}};

      default: ;
    endcase
  end

  // I really don't like this approach (below), since it doesn't
  // describe real RTL logic, it's closer to declarative approach,
  // when we set goals, not a way to achieve these goals.

  always_comb begin
    mem_be_o = 4'dx;

    case (core_size_i)
      LDST_B: mem_be_o = 4'b0001 << core_addr_i [1:0];
      LDST_H: mem_be_o = 4'b0011 << {core_addr_i [1], 1'b0};
      LDST_W: mem_be_o = 4'b1111;

      default: ;
    endcase
  end

  // ------------------
  // Drive read signals

  wire [3:0][ 7:0] mem_rd_bytes     = mem_rd_i;
  wire [1:0][15:0] mem_rd_halfwords = mem_rd_i;

  always_comb begin
    core_rd_o = 32'dx;

    case (core_size_i)
      LDST_B : core_rd_o = $signed(mem_rd_bytes [core_addr_i [1:0]]);
      LDST_H : core_rd_o = $signed(mem_rd_halfwords [core_addr_i [1]]);
      LDST_W : core_rd_o = mem_rd_i;
      LDST_BU: core_rd_o = mem_rd_bytes [core_addr_i [1:0]];
      LDST_HU: core_rd_o = mem_rd_halfwords [core_addr_i [1]];

      default: ;
    endcase
  end

  // ------------------
  // Drive stall signal

  logic core_stall_r, core_stall_next;
  assign core_stall_o = core_stall_next;

  always_comb begin
    core_stall_next = core_stall_r;

    if (core_req_i & ~ core_stall_r)
      core_stall_next = 1'b1;
    else if (mem_ready_i)
      core_stall_next = 1'b0;
  end

  always_ff @ (posedge clk_i)
    if (rst_i)
      core_stall_r <= 1'b0;
    else
      core_stall_r <= core_stall_next;

endmodule
