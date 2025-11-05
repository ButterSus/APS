/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Nikita Bulavin
* Email(s)       : nekkit6@edu.miet.ru

See https://github.com/MPSU/APS/blob/master/LICENSE file for licensing details.
* ------------------------------------------------------------------------------
*/
module lab_07_tb_processor_system();

    reg clk;
    reg rst;

    processor_system DUT(
    .clk_i(clk),
    .rst_i(rst)
    );

  initial clk = 0;
    always #10 clk = ~clk;
    initial begin
      $display( "Test has been started.\n");
      rst = 1;
      #40;
      rst = 0;

      // Wait until either 12800 time units pass, or EBREAK instruction is seen
      fork
        begin
          #12800;
          $display("The test time limit reached. Ending simulation.\n");
        end
        begin
          wait (DUT.core.instr_i == decoder_pkg::EBREAK);
          $display("EBREAK detected, ending simulation early.\n");
        end
      join_any
      $finish;

      #5;
        $display("You're trying to run simulation that has finished. Aborting simulation.\n");
      $fatal();
  end

stall_seq: assert property (
    @(posedge DUT.core.clk_i) disable iff ( DUT.core.rst_i )
    DUT.core.mem_req_o |-> (DUT.core.stall_i || $past(DUT.core.stall_i))
)else $error("incorrect implementation of stall signal\n");

stall_seq_fall: assert property (
  @(posedge DUT.core.clk_i) disable iff ( DUT.core.rst_i )
    (DUT.core.stall_i) |=> !DUT.core.stall_i
)else $error("stall must fall exact one cycle after rising\n");
endmodule
