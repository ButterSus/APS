module instr_mem (
    input  logic [31:0] read_addr_i,
    output logic [31:0] read_data_o
);

  import memory_pkg::*;

  localparam int Width = $clog2(INSTR_MEM_SIZE_BYTES);

  logic [31:0] rom [INSTR_MEM_SIZE_WORDS];

  // initial begin
  //   $readmemh("program.rom.mem", rom);
  // end

  initial begin
    $readmemh("lab_13_rx_led_instr.mem", rom);
  end

  assign read_data_o = rom [read_addr_i[Width - 1:2]];

endmodule
