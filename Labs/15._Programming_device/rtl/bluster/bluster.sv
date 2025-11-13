module bluster (
    input logic clk_i,
    input logic rst_i,

    input  logic rx_i,
    output logic tx_o,

    output logic [31:0] instr_addr_o,
    output logic [31:0] instr_wdata_o,
    output logic        instr_we_o,

    input  logic        data_ready_i,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    output logic        data_we_o,

    output logic core_reset_o
);

  // I added mem_ready signals, but didn't implement them
  // as there's no need for them now (but it'd gud to implement it).

  import memory_pkg::INSTR_MEM_SIZE_BYTES;
  import bluster_pkg::INIT_MSG_SIZE;
  import bluster_pkg::FLASH_MSG_SIZE;
  import bluster_pkg::ACK_MSG_SIZE;

  // -----------------
  // General variables

  logic rx_busy, rx_valid, tx_busy, tx_valid;
  logic [7:0] rx_data, tx_data;

  logic [5:0]      msg_counter;                  // How many chars left to send
  logic [31:0]     size_counter, flash_counter;  // How many bytes left to receive

  logic [3:0][7:0] flash_size_r, flash_addr_r;   // Details of flashing
  logic [15:0] flash_addr_h, flash_addr_l;

  assign flash_addr_h = { flash_addr_r [3], flash_addr_r [2] };
  assign flash_addr_l = { flash_addr_r [1], flash_addr_r [0] };

  logic send_fin, size_fin, flash_fin, next_round;

  logic [INIT_MSG_SIZE-1:0][7:0] init_msg;
  logic [FLASH_MSG_SIZE-1:0][7:0] flash_msg;

  // Bluster FSM
  // -----------

  assign send_fin   = (msg_counter   ==  6'd0) && !tx_busy;
  assign size_fin   = (size_counter  == 32'd0) && !rx_busy;
  assign flash_fin  = (flash_counter == 32'd0) && !rx_busy;
  assign next_round = (flash_addr_r  != 32'hFFFFFFFF) && !rx_busy;

  enum logic [2:0]
  {
    RCV_NEXT_COMMAND,  // This state also receives start address for flashing
    INIT_MSG,
    RCV_SIZE,
    SIZE_ACK,
    FLASH,
    FLASH_ACK,
    FINISH
  }
  state, next_state;

  always_comb begin
    next_state = state;

    case (state)
      RCV_NEXT_COMMAND : begin
        if (size_fin &~ next_round)
          next_state = FINISH;
        if (size_fin & next_round)
          next_state = INIT_MSG;
      end

      INIT_MSG : begin
        if (send_fin)
          next_state = RCV_SIZE;
      end

      RCV_SIZE : begin
        if (size_fin)
          next_state = SIZE_ACK;
      end

      SIZE_ACK : begin
        if (send_fin)
          next_state = FLASH;
      end

      FLASH : begin
        if (flash_fin)
          next_state = FLASH_ACK;
      end

      FLASH_ACK : begin
        if (send_fin)
          next_state = RCV_NEXT_COMMAND;
      end

      default :;
    endcase
  end

  always_ff @ (posedge clk_i)
    if (rst_i)
      state <= RCV_NEXT_COMMAND;
    else
      state <= next_state;

  // Counters logic
  // --------------

  // I kinda disagree with manual. You do need to
  // set counters' state only during state entering.

  // To write such logic, you really need to have
  // FSM transitions diagram, without it it's really
  // easy to mess things up.

  always_ff @ (posedge clk_i)
    if ( rst_i |
         (state == FLASH_ACK) & send_fin |
         (state == INIT_MSG)  & send_fin )
      size_counter <= 32'd4;
    else if ( ((state == RCV_NEXT_COMMAND) |
               (state == RCV_SIZE)) & rx_valid )
      size_counter <= size_counter - 1;

  always_ff @ (posedge clk_i)
    if ( (state == SIZE_ACK) & send_fin )
      flash_counter <= flash_size_r;
    else if ( (state == FLASH) & rx_valid )
      flash_counter <= flash_counter - 1;

  // I find it weird that we assign SIZE - 1 and not SIZE, huh?
  // Design flaw?

  always_ff @ (posedge clk_i)
    if ( (state == RCV_NEXT_COMMAND) & size_fin & next_round )
      msg_counter <= INIT_MSG_SIZE - 1;
    else if ( (state == RCV_SIZE) & size_fin )
      msg_counter <= ACK_MSG_SIZE - 1;
    else if ( (state == FLASH) & flash_fin )
      msg_counter <= FLASH_MSG_SIZE - 1;
    else if ( ((state == INIT_MSG) |
               (state == SIZE_ACK) |
               (state == FLASH_ACK)) & tx_valid )
      msg_counter <= msg_counter - 1;

  // Message generation
  // ------------------

  always_comb begin
    tx_valid = 1'b0;
    tx_data  = 8'dx;

    case (state)
      INIT_MSG : begin
        tx_valid = ~tx_busy;
        tx_data  = init_msg     [msg_counter];
      end

      SIZE_ACK : begin
        tx_valid = ~tx_busy;
        tx_data  = flash_size_r [msg_counter];
      end

      FLASH_ACK : begin
        tx_valid = ~tx_busy;
        tx_data  = flash_msg    [msg_counter];
      end

      default :;
    endcase
  end

  // Acknowledgement response generation
  // -----------------------------------

  logic [7:0][7:0] flash_size_ascii, flash_addr_ascii;

  // Dayom this systemverilog feature is fire
  function automatic logic [7:0] nibble_to_ascii(input logic [3:0] nibble);
    nibble_to_ascii = (nibble < 4'ha) ? (nibble + "0") : (nibble + "a" - 4'ha);
  endfunction

  genvar i;
  generate
    // [0-15] to ['0'-'9']['a'-'f']
    for(i = 0; i < 4; i = i + 1) begin : gen_nibble_to_ascii
      assign flash_size_ascii [i*2]   = nibble_to_ascii ( flash_size_r [i][3:0] );
      assign flash_size_ascii [i*2+1] = nibble_to_ascii ( flash_size_r [i][7:4] );
      assign flash_addr_ascii [i*2]   = nibble_to_ascii ( flash_addr_r [i][3:0] );
      assign flash_addr_ascii [i*2+1] = nibble_to_ascii ( flash_addr_r [i][7:4] );
    end
  endgenerate

  assign init_msg = { "ready for flash starting from 0x", flash_addr_ascii, "\n" };

  assign flash_msg = { "finished write 0x", flash_size_ascii,
                       " bytes starting from 0x", flash_addr_ascii, "\n" };

  // Memory interface driver (Memory map)
  // -----------------------

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      instr_addr_o  <= 32'd0;
      instr_wdata_o <= 32'd0;
      instr_we_o    <= 1'b0;
    end
    else if ((state == FLASH) & (flash_addr_h == 16'h0000) & rx_valid) begin
      instr_addr_o  <={ 16'd0, 16'(flash_addr_l + flash_counter - 1) };
      instr_wdata_o <= { instr_wdata_o [23:0], rx_data };
      instr_we_o    <= (flash_counter [1:0] == 2'b01);
    end
    else
      instr_we_o    <= 1'b0;

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      data_addr_o  <= 32'd0;
      data_wdata_o <= 32'd0;
      data_we_o    <= 1'b0;
    end
    else if ((state == FLASH) & (flash_addr_h == 16'h0080) & rx_valid) begin
      data_addr_o  <= { 16'd0, 16'(flash_addr_l + flash_counter - 1) };
      data_wdata_o <= { data_wdata_o [23:0], rx_data };
      data_we_o    <= (flash_counter [1:0] == 2'b01);
    end
    else
      data_we_o    <= 1'b0;

  // Metadata receiver
  // -----------------

  always_ff @ (posedge clk_i)
    if (rst_i)
      flash_size_r <= 32'd0;
    else if ((state == RCV_SIZE) & rx_valid)
      flash_size_r <= { flash_size_r [2:0], rx_data };

  always_ff @ (posedge clk_i)
    if (rst_i)
      flash_addr_r <= 32'd0;
    else if ((state == RCV_NEXT_COMMAND) & rx_valid)
      flash_addr_r <= { flash_addr_r [2:0], rx_data };

  // UART drivers
  // ------------

  uart_rx i_rx
  (
    .clk_i       ( clk_i      ),
    .rst_i       ( rst_i      ),
    .rx_i        ( rx_i       ),
    .busy_o      ( rx_busy    ),
    .baudrate_i  ( 17'd115200 ),
    .parity_en_i ( 1'b1       ),
    .stopbit_i   ( 2'd1       ),
    .rx_data_o   ( rx_data    ),
    .rx_valid_o  ( rx_valid   )
  );

  uart_tx i_tx
  (
    .clk_i       ( clk_i      ),
    .rst_i       ( rst_i      ),
    .tx_o        ( tx_o       ),
    .busy_o      ( tx_busy    ),
    .baudrate_i  ( 17'd115200 ),
    .parity_en_i ( 1'b1       ),
    .stopbit_i   ( 2'd1       ),
    .tx_data_i   ( tx_data    ),
    .tx_valid_i  ( tx_valid   )
  );

  // ------------
  // Output logic (rest)

  assign core_reset_o = (state != FINISH);

endmodule
