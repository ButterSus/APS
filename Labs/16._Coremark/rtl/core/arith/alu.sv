module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [ 4:0] alu_op_i,
    output logic        flag_o,
    output logic [31:0] result_o
);

  import alu_opcodes_pkg::*;  // импорт параметров, содержащих
                              // коды операций для АЛУ

  wire [31:0] sum;
  wire fa32_cout;

  fulladder32 i_fa32
  (
    .a_i     ( a_i  ),
    .b_i     ( b_i  ),
    .carry_i ( 1'b0 ),
    .sum_o   ( sum  ),
    .carry_o ( cout )
  );

  always_comb
    case (alu_op_i)
      ALU_ADD  : result_o = sum;
      ALU_SUB  : result_o = a_i - b_i;
      ALU_SLL  : result_o = a_i <<  b_i[4:0];
      // ALU_SLTS : result_o = { ~a_i[15], a_i[14:0] } < { ~b_i[15], b_i[14:0] };
      ALU_SLTS : result_o = $signed(a_i) < $signed(b_i);
      ALU_SLTU : result_o = $unsigned(a_i) < $unsigned(b_i);
      ALU_XOR  : result_o = a_i ^ b_i;
      ALU_SRL  : result_o = a_i >>  b_i[4:0];
      // There we actually need to make sure number is signed, even
      // though arithmetic shift otherwise doesn't make sense lol
      ALU_SRA  : result_o = $signed(a_i) >>> b_i[4:0];
      ALU_OR   : result_o = a_i | b_i;
      ALU_AND  : result_o = a_i & b_i;
      default  : result_o = 32'd0;
    endcase

  always_comb
    case (alu_op_i)
      ALU_EQ  : flag_o = (a_i == b_i);
      ALU_NE  : flag_o = (a_i != b_i);
      ALU_LTS : flag_o = $signed(a_i) <  $signed(b_i);
      ALU_GES : flag_o = $signed(a_i) >= $signed(b_i);
      ALU_LTU : flag_o = $unsigned(a_i) <  $unsigned(b_i);
      ALU_GEU : flag_o = $unsigned(a_i) >= $unsigned(b_i);
      default : flag_o = 1'b0;
    endcase

endmodule
