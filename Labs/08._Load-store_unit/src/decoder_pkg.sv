/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Andrei Solodovnikov
* Email(s)       : hepoh@org.miet.ru

See https://github.com/MPSU/APS/blob/master/LICENSE file for licensing details.
* ------------------------------------------------------------------------------
*/
package decoder_pkg;

  // dmem type load store
  // (aka. funct3 : LOAD & STORE)
  localparam LDST_B  = 3'b000;
  localparam LDST_H  = 3'b001;
  localparam LDST_W  = 3'b010;
  localparam LDST_BU = 3'b100;
  localparam LDST_HU = 3'b101;

endpackage
