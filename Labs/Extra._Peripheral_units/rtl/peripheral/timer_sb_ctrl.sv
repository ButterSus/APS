// Modification to CFG_ADDR:
// - bits [1:0] : interrupt mode
// - bits [  2] : hold interrupt till return?
// - bits [  3] : keep interrupting when repeat_counter == 0?

module timer_sb_ctrl (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        req_i,
    input  logic        write_enable_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] write_data_i,
    output logic [31:0] read_data_o,

    input  logic        irq_ret_i,
    output logic        irq_req_o
);

  localparam bit [23:0] TIME_L_ADDR    = 24'h00;
  localparam bit [23:0] TIME_H_ADDR    = 24'h04;
  localparam bit [23:0] DELAY_L_ADDR   = 24'h08;
  localparam bit [23:0] DELAY_H_ADDR   = 24'h0C;
  localparam bit [23:0] CFG_ADDR       = 24'h10;
  localparam bit [23:0] IRQ_TIMES_ADDR = 24'h14;
  localparam bit [23:0] RESET_ADDR     = 24'h24;

  wire ext_rst = (req_i & write_enable_i) & (addr_i [23:0] == RESET_ADDR);

  // ------------
  // Driver logic

  logic [63:0] system_counter;

  always_ff @ (posedge clk_i)
    if (rst_i)
      system_counter <= 64'd0;
    else
      system_counter <= system_counter + 64'd1;

  // -------------
  // Register file

  logic [63:0] delay;
  logic [31:0] repeat_counter;
  logic [63:0] system_counter_at_start;

  wire timeout = (system_counter == system_counter_at_start + delay);

  typedef enum logic [1:0]
  {
    OFF     = 2'b00,
    NTIMES  = 2'b01,
    FOREVER = 2'b10
  }
  irq_gen_mode_t;
  irq_gen_mode_t irq_gen_mode;

  typedef enum logic
  {
    PULSE = 1'b0,
    HOLD  = 1'b1
  }
  irq_life_mode_t;
  irq_life_mode_t irq_life_mode;

  typedef enum logic
  {
    REPEAT = 1'b0,
    FINISH = 1'b1
  }
  last_repeat_mode_t;
  last_repeat_mode_t last_repeat_mode;

  always_ff @ (posedge clk_i)
    if (rst_i | ext_rst) begin
      delay            <= 64'd0;
      irq_gen_mode     <= OFF;
      irq_life_mode    <= PULSE;
      last_repeat_mode <= REPEAT;
    end
    else if (req_i & write_enable_i)
      case (addr_i [23:0])
        DELAY_L_ADDR : delay [31: 0] <= write_data_i;
        DELAY_H_ADDR : delay [63:32] <= write_data_i;
        CFG_ADDR       : begin
          irq_gen_mode     <= irq_gen_mode_t'(write_data_i [1:0]);
          irq_life_mode    <= irq_life_mode_t'(write_data_i [2]);
          last_repeat_mode <= last_repeat_mode_t'(write_data_i [3]);

          if (irq_gen_mode_t'(write_data_i [1:0]) != OFF)
            system_counter_at_start <= system_counter;
        end
        IRQ_TIMES_ADDR : begin
          repeat_counter <= write_data_i;
          system_counter_at_start <= system_counter;
        end
        default :;
      endcase
    else if (timeout) begin
      repeat_counter <= repeat_counter != 32'd0 ? repeat_counter - 1 : 32'd0;
      system_counter_at_start <= system_counter;
    end

  // ----------------
  // Interrupts logic

  logic irq_req_gen;

  always_comb begin
    irq_req_gen = 1'b0;

    if ( (irq_gen_mode == FOREVER |
          irq_gen_mode == NTIMES &
            (repeat_counter != 32'd0 |
             last_repeat_mode == REPEAT )) &
          timeout )
      irq_req_gen = 1'b1;
  end

  logic irq_req_r;

  always_ff @ (posedge clk_i)
    if (rst_i)
      irq_req_r <= 1'b0;
    else if (irq_req_gen &~ irq_req_r & (irq_life_mode == HOLD))
      irq_req_r <= 1'b1;
    else if (irq_ret_i & irq_req_r | (irq_life_mode == PULSE))
      irq_req_r <= 1'b0;

  // ------------
  // Output logic

  always_ff @ (posedge clk_i)
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i &~ write_enable_i)
      case (addr_i [23:0])
        TIME_L_ADDR    : read_data_o <= system_counter [31: 0];
        TIME_H_ADDR    : read_data_o <= system_counter [63:32];
        DELAY_L_ADDR   : read_data_o <= delay [31: 0];
        DELAY_H_ADDR   : read_data_o <= delay [63:32];
        CFG_ADDR       : read_data_o <= { 28'd0, 1'(last_repeat_mode), 1'(irq_life_mode),
                                          2'(irq_gen_mode) };
        IRQ_TIMES_ADDR : read_data_o <= repeat_counter;
        default :;
      endcase

  assign irq_req_o = irq_req_gen | irq_req_r;

endmodule
