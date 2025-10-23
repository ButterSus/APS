module register_file (
    input logic clk_i,
    input logic write_enable_i,

    input logic [4:0] write_addr_i,
    input logic [4:0] read_addr1_i,
    input logic [4:0] read_addr2_i,

    input  logic [31:0] write_data_i,
    output logic [31:0] read_data1_o,
    output logic [31:0] read_data2_o
);

  logic [31:0] rf_mem [1:31];

  always_comb begin
    // I hope synthesis tool will figure out to avoid
    // initializing register [0] and put stub here.

    // PS; No, it doesn't, unfortunately, it will put mux
    // This makes sense mostly for FPGA with dedicated memory

    if (read_addr1_i == 5'd0)
      read_data1_o = 32'd0;
    else
      read_data1_o = rf_mem [read_addr1_i];
    if (read_addr2_i == 5'd0)
      read_data2_o = 32'd0;
    else
      read_data2_o = rf_mem [read_addr2_i];
  end

  always_ff @ (posedge clk_i) begin
    if (write_enable_i && write_addr_i != 5'd0)
      rf_mem [write_addr_i] <= write_data_i;
  end

endmodule
