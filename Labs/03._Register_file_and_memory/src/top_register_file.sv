module top_register_file (
    input  logic clk_i,
    input  logic btnd_i,
    input  logic [15:0] sw_i,
    output logic [15:0] led_o
);

  register_file i_rf
  (
    .clk_i          ( clk_i        ),
    .write_enable_i ( btnd_i       ),
    .read_addr1_i   ( sw_i  [ 7:0] ),
    .read_data1_o   ( led_o [ 7:0] ),
    .write_addr_i   ( sw_i  [ 7:0] ),
    .write_data_i   ( sw_i  [15:8] )
  );

endmodule
