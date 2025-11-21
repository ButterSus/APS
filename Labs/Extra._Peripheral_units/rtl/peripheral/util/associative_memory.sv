module associative_memory #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 10,
    parameter int ADDR_W = $clog2(DEPTH)
) (
    input  logic                clk_i,
    input  logic                rst_i,

    input  logic [ADDR_W - 1:0] addr_i,
    output logic                addr_hit_o,
    output logic [ WIDTH - 1:0] tag_o,

    input  logic [ WIDTH - 1:0] tag_i,
    input  logic                push_i,
    input  logic                pop_i,
    output logic                tag_hit_o,

    output logic                empty_o
);

  // Tag search:
  // https://viterbi-web.usc.edu/www-classes/engr/ee-s/457/EE457_Classnotes/EE457_Chapter7/ee457_Ch7_P1_Cache/CAM.pdf

  // ---------------------
  // Per-address interface

  logic [WIDTH - 1:0] cam [DEPTH];
  logic [DEPTH - 1:0] vld;

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      addr_hit_o <= 1'b0;
    end
    else if (addr_i >= ADDR_W'(DEPTH)) begin
      addr_hit_o <= 1'b0;
    end
    else begin
      addr_hit_o <= vld [addr_i];
      tag_o      <= cam [addr_i];
    end

  // -----------------
  // Per-tag interface

  logic                tag_hit;
  logic [ADDR_W - 1:0] tag_addr;

  always_comb begin
    tag_hit  = 1'b0;
    tag_addr = ADDR_W'(0);

    for (int i = 0; i < DEPTH; i ++)
      if (vld [i] & (cam [i] == tag_i)) begin
        tag_hit  = 1'b1;
        tag_addr = ADDR_W'(i);
      end
  end

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      tag_hit_o <= 1'b0;
    end
    else begin
      tag_hit_o <= tag_hit;
    end

  assign empty_o = ~ (| vld);

  assert
    property (
      @(posedge clk_i)
      // Be careful in SVA, X propagation counts as assertion fail
      !((push_i === 1'b1) && (pop_i === 1'b1))
    )
    else
      $error("Pushed and popped associative memory at the same time");

  logic [ADDR_W - 1:0] next_tag_addr;
  logic [DEPTH  - 1:0] and_vld;

  always_comb begin
    next_tag_addr = ADDR_W'('x);
    and_vld       = DEPTH'('x);

    for (int i = 0; i < DEPTH; i ++)
      if (i == 0)
        and_vld [i] = vld [i];
      else
        and_vld [i] = and_vld [i - 1] & vld [i];

    for (int i = 0; i < DEPTH; i ++)
      if ((i == 0) &~ vld [0])
        next_tag_addr = ADDR_W'(i);
      else if (~vld [i] & (and_vld [i - 1]))
        next_tag_addr = ADDR_W'(i);
  end

  always_ff @ (posedge clk_i)
    if (rst_i) begin
      for (int i = 0; i < DEPTH; i ++)
        vld [i] <= 1'b0;
    end
    else if (push_i &~ tag_hit) begin
      cam [next_tag_addr] <= tag_i;
      vld [next_tag_addr] <= 1'b1;
    end
    else if (pop_i & tag_hit) begin
      vld [tag_addr] <= 1'b0;
    end

endmodule
