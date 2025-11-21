// Manual testbench, no ~FaNcY aSsErTs~ or simulation models
module tb_associative_memory ();

  parameter int WIDTH  = 8;
  parameter int DEPTH  = 10;
  parameter int ADDR_W = $clog2(DEPTH);

  logic                clk_i;
  logic                rst_i;
  logic [ADDR_W - 1:0] addr_i;
  logic [ WIDTH - 1:0] tag_i;
  logic                push_i;
  logic                pop_i;
  logic                addr_hit_o;
  logic [ WIDTH - 1:0] tag_o;
  logic                tag_hit_o;
  logic                empty_o;

  // Instantiate the DUT
  associative_memory #(
    .WIDTH  ( WIDTH  ),
    .DEPTH  ( DEPTH  ),
    .ADDR_W ( ADDR_W )
  ) dut (.*);

  // Clock generation
  initial clk_i = 1'b0;
  always #50ns clk_i = ~clk_i;

  // -----
  // Tasks

  task automatic reset();
    rst_i  <= 1'b1;
    addr_i <= ADDR_W'(0);
    tag_i  <= WIDTH'(0);
    push_i <= 1'b0;
    pop_i  <= 1'b0;

    @(posedge clk_i);
    rst_i  <= 1'b0;
  endtask

  task automatic push_tag(input logic [WIDTH - 1:0] tag);
    tag_i  <= tag;
    push_i <= 1'b1;

    @(posedge clk_i)
    push_i <= 1'b0;
  endtask

  task automatic pop_tag(input logic [WIDTH - 1:0] tag);
    tag_i <= tag;
    pop_i <= 1'b1;

    @(posedge clk_i)
    pop_i <= 1'b0;
  endtask

  task automatic check_invalid_addr(
    input logic [ADDR_W - 1:0] addr
  );
    addr_i <= addr;

    @(posedge clk_i)
    fork begin
      @(posedge clk_i);
      if (addr_hit_o !== 1'b0)
        $error("addr_hit_o mismatch at addr %0d: expected %b got %b",
               addr, 1'b0, addr_hit_o);
    end join_none
  endtask

  task automatic check_addr(
    input logic [ADDR_W - 1:0] addr,
    input logic [ WIDTH - 1:0] expected_tag
  );
    addr_i <= addr;

    @(posedge clk_i);

    // Funny though, I didn't ever thought about it,
    // we need to wait 2 cycles even though module
    // has delay of only 1 cycle. This is due to how
    // flip flops work mostly.

    // Since I'm crazy perfectionist when it comes to my
    // "high-level" code, I'll use fork join_none here to create
    // additional thread in order to avoid any extra delay
    // in-between of task calls. This is likely easily avoidable
    // in case you have UVM model (driver + monitor classes).

    fork begin
      @(posedge clk_i);
      if (addr_hit_o !== 1'b1)
        $error("addr_hit_o mismatch at addr %0d: expected %b got %b",
               addr, 1'b1, addr_hit_o);

      if (tag_o !== expected_tag)
        $error("tag_o mismatch at addr %0d: expected %b got %b",
               addr, expected_tag, tag_o);
    end join_none
  endtask

  task automatic assert_tag_hit(input logic expected_tag_hit);
    fork begin
      @(posedge clk_i);
      if (tag_hit_o !== expected_tag_hit)
        $error("tag_hit_o mismatch: expected %b got %b",
               expected_tag_hit, tag_hit_o);
    end join_none
  endtask

  task automatic assert_empty(input logic expected_empty);
    fork begin
      @(posedge clk_i);
      if (empty_o !== expected_empty)
        $error("empty mismatch: expected %b got %b",
               expected_empty, empty_o);
    end join_none
  endtask

  task automatic finish();
    repeat(5) @(posedge clk_i);
    $finish();
  endtask

  initial begin
    reset();
    push_tag(31);
    assert_tag_hit(0);
    check_addr(0, 31);

    reset();
    assert_empty(1);
    push_tag(0);
    assert_empty(0);
    push_tag(1);
    push_tag(2);
    push_tag(3);
    push_tag(4);

    // Push same tag
    push_tag(5);
    assert_tag_hit(0);
    assert_empty(0);
    push_tag(5);
    assert_tag_hit(1);
    assert_empty(0);
    push_tag(5);
    assert_tag_hit(1);
    assert_empty(0);

    push_tag(6);
    push_tag(7);
    push_tag(8);
    push_tag(9);
    assert_empty(0);

    // Push more than can hold
    push_tag(10);
    push_tag(11);
    push_tag(12);

    // Check correctness
    check_addr(0, 0);
    check_addr(1, 1);
    check_addr(2, 2);
    check_addr(3, 3);
    check_addr(4, 4);
    check_addr(5, 5);
    check_addr(6, 6);
    check_addr(7, 7);
    check_addr(8, 8);
    check_addr(9, 9);

    // Pop actions
    pop_tag(13);
    assert_tag_hit(0);
    pop_tag(3);
    assert_tag_hit(1);
    pop_tag(3);
    assert_tag_hit(0);
    pop_tag(2);
    assert_tag_hit(1);
    pop_tag(1);
    assert_tag_hit(1);
    check_invalid_addr(3);
    check_invalid_addr(2);
    check_invalid_addr(1);

    finish();
  end

endmodule
