`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.01.2019 11:29:15
// Design Name: 
// Module Name: axi_s_cordic_abs
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_s_cordic_abs #(
  parameter                             S_TDATA_WIDTH           = 32,
  parameter                             M_TDATA_WIDTH           = S_TDATA_WIDTH,
  parameter                             TID_WIDTH               = 2,
  //parameter                             TDEST_WIDTH             = M_TDATA_WIDTH/8,
  parameter                             PLATFORM                = "GENERIC",

  parameter                             IS_SIGNED_DATA_IN       = 1,

  parameter                             VECTOR_MODE_STAGES_QUAN = 17,
  parameter                             MULT_STAGES_QUANTITY    = 20, // 2 <= MULT_STAGES_QUANTITY <= 28, equal to number of "1" that corresponds to binary representation of coefficient "1/K" 
  parameter                             GUARD_BITS_QUANTITY     = 6,
  parameter                             MULT_GUARD_BITS         = 7
)( 
  // stream slave signals
  input                                 ss_clk_i,
  input                                 ss_aresetn_i,
  input                                 ss_tvalid_i,
  input                                 ss_tlast_i,
  input           [TID_WIDTH-1:0]       ss_tid_i,
  //input           [TDEST_WIDTH-1:0]     ss_tdest_i,

  input   signed  [S_TDATA_WIDTH-1:0]   ss_tdata_re_i,
  input   signed  [S_TDATA_WIDTH-1:0]   ss_tdata_im_i,

  output                                ss_tready_o,

  // stream master signals
  output                                sm_clk_o,
  output                                sm_aresetn_o,
  output                                sm_tvalid_o,
  output                                sm_tlast_o,
  output          [TID_WIDTH-1:0]       sm_tid_o,
  //output          [TDEST_WIDTH-1:0]     sm_tdest_o,

  output          [M_TDATA_WIDTH-1:0]   sm_tdata_o,
  
  input                                 sm_tready_i
);

localparam  STAGES_QUANTITY = VECTOR_MODE_STAGES_QUAN + 1 + MULT_STAGES_QUANTITY + 1;


reg     [STAGES_QUANTITY:1]   tvalid_delay;
reg     [STAGES_QUANTITY:1]   tlast_delay;
reg     [TID_WIDTH-1:0]       tid_delay      [STAGES_QUANTITY:1];
//reg     [TDEST_WIDTH-1:0]     tdest_delay    [STAGES_QUANTITY:1];

wire    [STAGES_QUANTITY:1]   ce_for_stage;


integer j;
always @( posedge ss_clk_i or negedge ss_aresetn_i )
  if ( !ss_aresetn_i ) begin
    for ( j = 1; j < STAGES_QUANTITY + 1; j = j + 1 ) begin
      tvalid_delay  [j] <= 1'd0;
      tlast_delay   [j] <= 1'd0;
      tid_delay     [j] <= { TID_WIDTH { 1'd0 } };
      //tdest_delay   [j] <= { TDEST_WIDTH { 1'd0 } };
    end
  end else begin
    if ( ce_for_stage[1] ) begin
      tvalid_delay  [1] <= ss_tvalid_i;
      tlast_delay   [1] <= ss_tlast_i;
      tid_delay     [1] <= ss_tid_i;
      //tdest_delay   [1] <= ss_tdest_i;
    end else if ( ce_for_stage[2] ) begin
      tvalid_delay  [1] <= 1'b0;
    end
    for ( j = 2; j < STAGES_QUANTITY; j = j + 1 ) 
      if ( ce_for_stage[j] ) begin
        tvalid_delay  [j] <= tvalid_delay  [j-1];
        tlast_delay   [j] <= tlast_delay   [j-1];
        tid_delay     [j] <= tid_delay     [j-1];
        //tdest_delay   [j] <= tdest_delay   [j-1];
      end else if ( ce_for_stage[j+1] ) begin
        tvalid_delay  [j] <= 1'b0;
      end
    if ( ce_for_stage[STAGES_QUANTITY] ) begin
      tvalid_delay  [STAGES_QUANTITY] <= tvalid_delay  [STAGES_QUANTITY-1];
      tlast_delay   [STAGES_QUANTITY] <= tlast_delay   [STAGES_QUANTITY-1];
      tid_delay     [STAGES_QUANTITY] <= tid_delay     [STAGES_QUANTITY-1];
      //tdest_delay   [STAGES_QUANTITY] <= tdest_delay   [STAGES_QUANTITY-1];
    end else if ( sm_tvalid_o && ss_tready_o ) begin
      tvalid_delay  [STAGES_QUANTITY] <= 1'b0;
      tlast_delay   [STAGES_QUANTITY] <= 1'b0;
    end
  end


cordic_abs #(
  .DATA_IN_WIDTH              ( S_TDATA_WIDTH           ),
  .DATA_OUT_WIDTH             ( M_TDATA_WIDTH           ),

  .IS_SIGNED_DATA_IN          ( IS_SIGNED_DATA_IN       ),

  .VECTOR_MODE_STAGES_QUAN    ( VECTOR_MODE_STAGES_QUAN ),
  .MULT_STAGES_QUANTITY       ( MULT_STAGES_QUANTITY    ),
  .GUARD_BITS_QUANTITY        ( GUARD_BITS_QUANTITY     ),
  .MULT_GUARD_BITS            ( MULT_GUARD_BITS         ),

  .PLATFORM                   ( PLATFORM                )
) cordic_abs_inst (
  .clk_i                      ( ss_clk_i                ),
  .areset_n_i                 ( ss_aresetn_i            ),
  .ce_i                       ( ce_for_stage            ),

  .data_a_i                   ( ss_tdata_re_i           ),
  .data_b_i                   ( ss_tdata_im_i           ),
  .data_abs_o                 ( sm_tdata_o              )
);


assign                    ce_for_stage    = { tvalid_delay[STAGES_QUANTITY-1:1] , ss_tvalid_i } & { STAGES_QUANTITY { ss_tready_o } };

assign                    ss_tready_o     = sm_tready_i;

assign                    sm_clk_o        = ss_clk_i;
assign                    sm_aresetn_o    = ss_aresetn_i;
assign                    sm_tvalid_o     = tvalid_delay  [STAGES_QUANTITY];
assign                    sm_tlast_o      = tlast_delay   [STAGES_QUANTITY];
assign                    sm_tid_o        = tid_delay     [STAGES_QUANTITY];
//assign                    sm_tdest_o      = tdest_delay   [STAGES_QUANTITY];

endmodule
