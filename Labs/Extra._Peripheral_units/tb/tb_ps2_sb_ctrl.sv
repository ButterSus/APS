module tb_ps2_sb_ctrl ();

  parameter int TIMEOUT_CYCLES = 400;
  parameter int REPEAT_CYCLES  = 200;

  logic        clk_i;
  logic        rst_i;
  logic        req_i;
  logic        write_enable_i;
  logic [31:0] addr_i;
  logic [31:0] write_data_i;
  logic [31:0] read_data_o;

  logic        irq_ret_i;
  logic        irq_req_o;

  logic        kclk_i;
  logic        kdata_i;

  // Testbench variables
  int pass_count = 0;
  int fail_count = 0;

  // Instantiate the DUT
  ps2_sb_ctrl #(
    .TIMEOUT_CYCLES ( TIMEOUT_CYCLES ),
    .REPEAT_CYCLES  ( REPEAT_CYCLES  )
  ) dut (.*);

  // Clock generation
  initial clk_i = 1'b0;
  always #50ns clk_i = ~clk_i;

  // -----
  // Tasks

  task automatic reset();
    rst_i            <= 1'b1;
    req_i            <= 1'b0;
    write_enable_i   <= 1'b0;
    addr_i           <= 32'dx;
    write_data_i     <= 32'dx;
    dut.keycode      <= 8'hxx;
    dut.driver_valid <= 1'b0;
    irq_ret_i        <= 1'b1;
    kclk_i           <= 1'b0;
    kdata_i          <= 1'b0;

    @(posedge clk_i);
    rst_i  <= 1'b0;
    repeat(2) @(posedge clk_i);
  endtask

  task automatic finish();
    repeat(5) @(posedge clk_i);
    $display("\n=== TEST SUMMARY ===");
    $display("Passed:    %0d", pass_count);
    $display("Failed:    %0d", fail_count);
    $display("====================\n");
    $finish();
  endtask

  // Task to simulate key press
  task automatic key_press(input logic [7:0] keycode);
    $display("[%t] Key press: 0x%02h", $time, keycode);

    dut.keycode <= keycode;
    dut.driver_valid <= 1'b1;
    @(posedge clk_i);
    dut.driver_valid <= 1'b0;
    dut.keycode <= 8'hxx;
  endtask

  // Task to simulate key press
  task automatic key_release(input logic [7:0] keycode);
    $display("[%t] Key release: 0x%02h", $time, keycode);

    dut.keycode <= 8'hF0;
    dut.driver_valid <= 1'b1;
    @(posedge clk_i);
    dut.driver_valid <= 1'b0;
    dut.keycode <= 8'hxx;

    repeat(5) @(posedge clk_i);

    dut.keycode <= keycode;
    dut.driver_valid <= 1'b1;
    @(posedge clk_i);
    dut.driver_valid <= 1'b0;
    dut.keycode <= 8'hxx;
  endtask

  // Task to check if IRQ occurs within timeout
  task automatic expect_irq(
    input int expected_keycode,
    input string test_name,
    input int timeout_cycles
  );
    fork
      begin : irq_test_block
        @(posedge clk_i iff irq_req_o === 1'b1);
        if (dut.keycode_out !== expected_keycode) begin
          $display("[%t] FAIL: %s - keycode doesn't match", $time, test_name);
          fail_count++;
          disable irq_test_block;
        end
        $display("[%t]  PASS: %s - IRQ asserted", $time, test_name);
        pass_count++;
      end

      begin
        repeat(timeout_cycles) @(posedge clk_i);
        $display("[%t]  FAIL: %s - IRQ not asserted within timeout", $time, test_name);
        fail_count++;
      end
    join_any
    disable fork;
    @(posedge clk_i);
  endtask

  // Task to check no IRQ occurs
  task automatic expect_no_irq(input string test_name, input int timeout_cycles);
    fork
      begin
        @(posedge clk_i iff irq_req_o === 1'b1);
        $display("[%t]  FAIL: %s - IRQ asserted when not expected", $time, test_name);
        fail_count++;
      end

      begin
        repeat(timeout_cycles) @(posedge clk_i);
        $display("[%t]  PASS: %s - No IRQ as expected", $time, test_name);
        pass_count++;
      end
    join_any
    disable fork;
    @(posedge clk_i);
  endtask

  task automatic test_single_key();
    $display("\n=== Test 1: Single Key Behavior ===");

    // Press key
    key_press(8'h1C); // 'A' key
    expect_irq(8'h1C, "Initial key press should generate IRQ", 5);

    // Wait for timeout interrupt
    $display("  Waiting for timeout interrupt...");
    expect_irq(8'h1C, "Should generate IRQ after TIMEOUT_CYCLES", TIMEOUT_CYCLES + 5);

    // Wait for repeat interrupt
    $display("  Waiting for repeat interrupt...");
    expect_irq(8'h1C, "Should generate IRQ after REPEAT_CYCLES", REPEAT_CYCLES + 5);

    // Wait for one more repeat
    $display("  Waiting for second repeat interrupt...");
    expect_irq(8'h1C, "Should generate second repeat IRQ", REPEAT_CYCLES + 5);
  endtask

  task automatic test_three_keys();
    $display("\n=== Test 2: Three Keys Timeout and Repeat ===");

    // Press three different keys
    key_press(8'h1C); // Key 1
    expect_irq(8'h1C, "Key 1 press should generate IRQ", 5);

    key_press(8'h32); // Key 2
    expect_irq(8'h32, "Key 2 press should generate IRQ", 5);

    key_press(8'h21); // Key 3
    expect_irq(8'h21, "Key 3 press should generate IRQ", 5);

    $display("  Waiting for timeout interrupts for all 3 keys...");

    // Expect timeout interrupts for all 3 keys
    expect_irq(8'h1C, "Key 1 timeout IRQ", TIMEOUT_CYCLES + 5);
    expect_irq(8'h32, "Key 2 timeout IRQ", 5);
    expect_irq(8'h21, "Key 3 timeout IRQ", 5);

    $display("  Waiting for repeat interrupts for all 3 keys...");

    // Expect repeat interrupts for all 3 keys
    expect_irq(8'h1C, "Key 1 repeat IRQ", REPEAT_CYCLES + 5);
    expect_irq(8'h32, "Key 2 repeat IRQ", 5);
    expect_irq(8'h21, "Key 3 repeat IRQ", 5);

    $display("  Waiting for repeat interrupts again...");

    // Again
    expect_irq(8'h1C, "Key 1 repeat IRQ", REPEAT_CYCLES + 5);
    expect_irq(8'h32, "Key 2 repeat IRQ", 5);
    expect_irq(8'h21, "Key 3 repeat IRQ", 5);
  endtask

  task automatic test_initial_key();
    $display("\n=== Test 3: Initial key press generated ===");

    key_press(8'hAA);
    expect_no_irq("Key press should not generate IRQ", 1000);
  endtask

  task automatic test_complex_multi_key();
    $display("\n=== Test 4: Complex multi-key ===");

    key_press("c");
    expect_irq("c", "Key 'c' press should generate IRQ", 5);

    key_release("c");
    repeat(5) @(posedge clk_i);

    key_press("a");
    expect_irq("a", "Key 'a' press should generate IRQ", 5);

    key_release("a");
    repeat(5) @(posedge clk_i);

    key_press("t");
    expect_irq("t", "Key 't' press should generate IRQ", 5);

    key_release("t");
    expect_no_irq("All keys are released", 100);

    key_press("1");
    expect_irq("1", "Key '1' press should generate IRQ", 5);

    key_release("1");
    repeat(5) @(posedge clk_i);

    key_press("2");
    expect_irq("2", "Key '2' press should generate IRQ", 5);

    key_release("2");
    repeat(5) @(posedge clk_i);

    key_press("3");
    expect_irq("3", "Key '3' press should generate IRQ", 5);

    expect_irq("3", "Key '3' after timeout", TIMEOUT_CYCLES + 5);
    expect_irq("3", "Key '3' after repeat", REPEAT_CYCLES + 5);
    expect_irq("3", "Key '3' after repeat", REPEAT_CYCLES + 5);
    expect_irq("3", "Key '3' after repeat", REPEAT_CYCLES + 5);
  endtask

  task automatic test_irq_ret();
    $display("\n=== Test 4: IRQ return ===");

    key_press("c");
    expect_irq("c", "Key 'c' press should generate IRQ", 5);

    key_press("a");
    expect_irq("a", "Key 'a' press should generate IRQ", 5);

    key_press("t");
    expect_irq("t", "Key 't' press should generate IRQ", 5);

    irq_ret_i <= 1'b0;
    expect_irq("c", "Key 'c' after timeout", TIMEOUT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);
    expect_irq("a", "Key 'a' after repeat", REPEAT_CYCLES + 5);
    irq_ret_i <= 1'b0;
    expect_irq("t", "Key 't' after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    expect_irq("c", "Key 'c' after timeout", TIMEOUT_CYCLES + 5);
    irq_ret_i <= 1'b0;
    expect_irq("a", "Key 'a' after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);
    expect_irq("t", "Key 't' after repeat", REPEAT_CYCLES + 5);

    irq_ret_i <= 1'b0;
    expect_irq("c", "Key 'c' after timeout", TIMEOUT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);
    irq_ret_i <= 1'b0;
    expect_irq("a", "Key 'a' after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);
    irq_ret_i <= 1'b0;
    expect_irq("t", "Key 't' after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);
    irq_ret_i <= 1'b0;
  endtask

  task automatic test_many_keys();
    $display("\n=== Test 5: Many Timeout and Repeat ===");

    $display("Pressing 10 keys");

    key_press("1");
    expect_irq("1", "1 press should generate IRQ", 5);
    key_press("2");
    expect_irq("2", "2 press should generate IRQ", 5);
    key_press("3");
    expect_irq("3", "3 press should generate IRQ", 5);
    key_press("4");
    expect_irq("4", "4 press should generate IRQ", 5);
    key_press("5");
    expect_irq("5", "5 press should generate IRQ", 5);
    key_press("6");
    expect_irq("6", "6 press should generate IRQ", 5);
    key_press("7");
    expect_irq("7", "7 press should generate IRQ", 5);
    key_press("8");
    expect_irq("8", "8 press should generate IRQ", 5);
    key_press("9");
    expect_irq("9", "9 press should generate IRQ", 5);
    key_press("0");
    expect_irq("0", "0 press should generate IRQ", 5);

    $display("Waiting timeout");

    irq_ret_i <= 1'b0;
    expect_irq("1", "1 after timeout", TIMEOUT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("2", "2 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("3", "3 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("4", "4 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("5", "5 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("6", "6 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("7", "7 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("8", "8 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("9", "9 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("0", "0 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    $display("Waiting repeat");

    irq_ret_i <= 1'b0;
    expect_irq("1", "1 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("2", "2 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("3", "3 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("4", "4 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("5", "5 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("6", "6 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("7", "7 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("8", "8 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("9", "9 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

    irq_ret_i <= 1'b0;
    expect_irq("0", "0 after repeat", REPEAT_CYCLES + 5);
    repeat (200) @(posedge clk_i);
    irq_ret_i <= 1'b1;
    @(posedge clk_i);

  endtask

  // Main test sequence
  initial begin
    $display("Starting PS/2 Controller Simplified Tests");
    reset();
    test_single_key();
    reset();
    test_three_keys();
    reset();
    test_initial_key();
    reset();
    test_complex_multi_key();
    reset();
    test_irq_ret();
    reset();
    test_many_keys();
    finish();
  end

  // Timeout protection
  initial begin
    #5ms;
    $display("\n[%t]: Simulation timeout!", $time);
    fail_count++;
    finish();
  end

endmodule
