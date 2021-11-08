`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2019 16:44:00
// Design Name: 
// Module Name: cordic_abs
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


module cordic_abs #(
  parameter                                                                         DATA_IN_WIDTH           = 32,
  parameter                                                                         DATA_OUT_WIDTH          = DATA_IN_WIDTH,

  parameter                                                                         IS_SIGNED_DATA_IN       = 1,

  parameter                                                                         VECTOR_MODE_STAGES_QUAN = 17,
  parameter                                                                         MULT_STAGES_QUANTITY    = 20, // 2 <= MULT_STAGES_QUANTITY <= 28, equal to number of "1" that corresponds to binary representation of coefficient "1/K" 
  parameter                                                                         GUARD_BITS_QUANTITY     = 6,
  parameter                                                                         MULT_GUARD_BITS         = 7,

  parameter                                                                         PLATFORM                = "GENERIC"
)(
  input                                                                             clk_i,
  input                                                                             areset_n_i,
  input                 [VECTOR_MODE_STAGES_QUAN + 1 + MULT_STAGES_QUANTITY + 1:1]  ce_i,

  input       signed    [DATA_IN_WIDTH-1:0]                                         data_a_i,
  input       signed    [DATA_IN_WIDTH-1:0]                                         data_b_i,
  output reg            [DATA_OUT_WIDTH-1:0]                                        data_abs_o
);

localparam  VECTOR_MODE_ROUNDING_IS_USED    = 1;

localparam  WORK_WIDTH                      = DATA_IN_WIDTH + 2 + GUARD_BITS_QUANTITY;


wire        [WORK_WIDTH-1:0]      x_comb;
wire        [WORK_WIDTH-1:0]      y_comb;

// Obtaining of equivalent length vector with | angle | <= pi/2
generate
  if ( IS_SIGNED_DATA_IN ) begin
    assign  x_comb = { 2'd0, ( data_a_i[DATA_IN_WIDTH-1] ) ? ( -data_a_i ) : ( data_a_i ) } << GUARD_BITS_QUANTITY;
    assign  y_comb = { {2{data_b_i[DATA_IN_WIDTH-1]}}, data_b_i } << GUARD_BITS_QUANTITY;
  end
  else begin
    assign  x_comb = { 2'd0, data_a_i } << GUARD_BITS_QUANTITY;
    assign  y_comb = { 2'd0, data_b_i } << GUARD_BITS_QUANTITY;
  end
endgenerate


// CORDIC vector mode implementation (begin)

/*  It's proved, that if A is an integer and B = int_part(B) + frac_part(B) then 
    operations with rounding are implemented by
      int_part(A + B) = int_part(A) + int_part( B) +  R
      int_part(A - B) = int_part(A) + int_part(~B) + ~R
    where R is most significant bit of fract_part(B) 
*/

reg         [WORK_WIDTH-1:0]      x_vector                [VECTOR_MODE_STAGES_QUAN:0];
reg         [WORK_WIDTH-1:0]      y_vector                [VECTOR_MODE_STAGES_QUAN:0];

wire        [WORK_WIDTH-1:0]      x_vector_comb           [VECTOR_MODE_STAGES_QUAN:1];
wire        [WORK_WIDTH-1:0]      y_vector_comb           [VECTOR_MODE_STAGES_QUAN:1];

wire        [WORK_WIDTH-1:0]      x_vector_shift_comb     [VECTOR_MODE_STAGES_QUAN-1:1];
wire        [WORK_WIDTH-1:0]      y_vector_shift_comb     [VECTOR_MODE_STAGES_QUAN-1:1];

assign  x_vector_comb[1]  = ( y_vector[0][WORK_WIDTH-1] ) ? ( x_vector[0] - y_vector[0] ) : ( x_vector[0] + y_vector[0] );
assign  y_vector_comb[1]  = ( y_vector[0][WORK_WIDTH-1] ) ? ( y_vector[0] + x_vector[0] ) : ( y_vector[0] - x_vector[0] );

generate
  genvar i;
  for ( i = 1; i < VECTOR_MODE_STAGES_QUAN; i = i + 1 ) begin
    
    assign  x_vector_shift_comb         [i] = { {i{                     1'b0}}, x_vector[i][WORK_WIDTH-1:i] };
    assign  y_vector_shift_comb         [i] = { {i{y_vector[i][WORK_WIDTH-1]}}, y_vector[i][WORK_WIDTH-1:i] };

    if ( VECTOR_MODE_ROUNDING_IS_USED ) begin
      assign  x_vector_comb[i+1]  = ( y_vector[i][WORK_WIDTH-1] ) ? ( x_vector[i] + ~y_vector_shift_comb[i] + !y_vector[i][i-1] ) :
                                                                    ( x_vector[i] +  y_vector_shift_comb[i] +  y_vector[i][i-1] );

      assign  y_vector_comb[i+1]  = ( y_vector[i][WORK_WIDTH-1] ) ? ( y_vector[i] +  x_vector_shift_comb[i] +  x_vector[i][i-1] ) :
                                                                    ( y_vector[i] + ~x_vector_shift_comb[i] + !x_vector[i][i-1] );
    end
    else begin
      assign  x_vector_comb[i+1]  = ( y_vector[i][WORK_WIDTH-1] ) ? ( x_vector[i] - y_vector_shift_comb[i] ) :
                                                                    ( x_vector[i] + y_vector_shift_comb[i] );

      assign  y_vector_comb[i+1]  = ( y_vector[i][WORK_WIDTH-1] ) ? ( y_vector[i] + x_vector_shift_comb[i] ) :
                                                                    ( y_vector[i] - x_vector_shift_comb[i] );
    end
  end    
endgenerate

integer j;
always @( posedge clk_i or negedge areset_n_i ) 
  if ( !areset_n_i ) begin
    x_vector[0] <= { WORK_WIDTH { 1'd0 } };
    y_vector[0] <= { WORK_WIDTH { 1'd0 } };
  end else begin
    if ( ce_i[1] ) begin
      x_vector[0] <= x_comb;
      y_vector[0] <= y_comb;
    end
    for ( j = 1; j < VECTOR_MODE_STAGES_QUAN + 1; j = j + 1 ) 
      if ( ce_i[j+1] ) begin
        x_vector[j] <= x_vector_comb[j];
        y_vector[j] <= y_vector_comb[j];
      end
  end

// CORDIC vector mode implementation (end)

// Multiplication by a coefficient (begin)

// Now multiplication implemented using a simplified multiplier, so quantity of muluplication stages equal to quantity of "1" of coefficient
// Coefficient value is 0.10011011011101001110110110101000010000110101111001100...
// coefficient = sum( 2 ** -( shamt_of_stage[i] ) ), where i from [1 .. MULT_STAGES_QUANTITY]

function [31:0] get_shamt_of_stage(
  input [31:0] stage_number
);
  reg   [52:0]  coefficient;
  integer       cur_shamt, cur_stage;  
  
  begin
    coefficient = 53'b10011011011101001110110110101000010000110101111001100;
    cur_shamt   = 0;
    cur_stage   = 0;
    while ( stage_number > cur_stage ) begin
      if ( coefficient[52 - cur_shamt] )
        cur_stage = cur_stage + 1;
      cur_shamt = cur_shamt + 1;
    end
    get_shamt_of_stage = cur_shamt;
  end
endfunction

/*
function [31:0] my_clog2(
  input [31:0] n
);
  integer cur_deg;

  begin
    cur_deg = 0;
    while ( n > 2**cur_deg )
      cur_deg = cur_deg + 1;
    my_clog2 = cur_deg;
  end
endfunction
*/

generate
  if ( ( MULT_STAGES_QUANTITY < 2 ) || ( 28 < MULT_STAGES_QUANTITY ) )
    illegal_mult_stages_quantity_parameter_at_cordic_abs non_existing_module();
endgenerate

generate
  genvar k;
    wire  [5:0]   shamt_of_stage  [MULT_STAGES_QUANTITY:1];
    for ( k = 1; k < MULT_STAGES_QUANTITY + 1; k = k + 1 ) begin
      assign  shamt_of_stage[k] = get_shamt_of_stage( k );
    end
endgenerate


localparam  CORDIC_RES_WIDTH      = DATA_IN_WIDTH + 2;

// Here it is taken into account that get_shamt_of_stage( 1 ) is 1 
localparam  MULT_STAGE_REG_WIDTH  = DATA_IN_WIDTH + 2 + MULT_GUARD_BITS;


wire        [CORDIC_RES_WIDTH-1:0]      cordic_result = x_vector[VECTOR_MODE_STAGES_QUAN] >> GUARD_BITS_QUANTITY;

reg         [MULT_STAGE_REG_WIDTH-1:0]  result_of_stage [MULT_STAGES_QUANTITY:1];
reg         [CORDIC_RES_WIDTH-1:0]      value_for_stage [MULT_STAGES_QUANTITY:2];

integer i1;
always @( posedge clk_i or negedge areset_n_i )
  if ( !areset_n_i ) begin
    value_for_stage[2] <= { CORDIC_RES_WIDTH { 1'b0 } };
  end else begin
    if ( ce_i[VECTOR_MODE_STAGES_QUAN + 2] ) begin
      value_for_stage[2] <= cordic_result;
    end
    for ( i1 = 3; i1 < MULT_STAGES_QUANTITY + 1; i1 = i1 + 1 ) 
      if ( ce_i[VECTOR_MODE_STAGES_QUAN + i1] ) begin
        value_for_stage[i1] <= value_for_stage[i1-1];
      end
  end

integer j1;
always @( posedge clk_i or negedge areset_n_i )
  if ( !areset_n_i ) begin
    result_of_stage[1] <= { MULT_STAGE_REG_WIDTH { 1'b0 } };
  end else begin
    if ( ce_i[VECTOR_MODE_STAGES_QUAN + 2] ) begin
      result_of_stage[1] <= ( cordic_result << MULT_GUARD_BITS ) >> shamt_of_stage[1];
    end
    for ( j1 = 2; j1 < MULT_STAGES_QUANTITY + 1; j1 = j1 + 1 ) 
      if ( ce_i[VECTOR_MODE_STAGES_QUAN + 1 + j1] ) begin
        result_of_stage[j1] <= result_of_stage[j1-1] + ( ( value_for_stage[j1] << MULT_GUARD_BITS ) >> shamt_of_stage[j1] );
      end
  end

// Multiplication by a coefficient (end)

// Abs width adaptation according to DATA_OUT_WIDTH (begin)

localparam  RESULT_WIDTH          = ( IS_SIGNED_DATA_IN ) ? ( DATA_IN_WIDTH ) : ( DATA_IN_WIDTH + 1 );

wire        [DATA_OUT_WIDTH-1:0]        adapted_result;
wire        [RESULT_WIDTH-1:0]          unadapted_result;

assign    unadapted_result = result_of_stage[MULT_STAGES_QUANTITY] >> MULT_GUARD_BITS;
localparam  ADDITIONAL_SHAMT  = RESULT_WIDTH - DATA_OUT_WIDTH;
localparam  ZEROS_QUANTITY    = DATA_OUT_WIDTH - RESULT_WIDTH;

generate
  if ( RESULT_WIDTH >= DATA_OUT_WIDTH ) begin    
    assign      adapted_result    = unadapted_result >> ADDITIONAL_SHAMT;
  end
  else begin
    assign      adapted_result    = { { ZEROS_QUANTITY { 1'b0 } }, unadapted_result };
  end
endgenerate

always @( posedge clk_i or negedge areset_n_i )
  if ( !areset_n_i )
    data_abs_o <= { DATA_OUT_WIDTH { 1'd0 } };
  else if ( ce_i[VECTOR_MODE_STAGES_QUAN + 1 + MULT_STAGES_QUANTITY + 1] )
    data_abs_o <= adapted_result;

// Abs width adaptation according to DATA_OUT_WIDTH (end) 

endmodule