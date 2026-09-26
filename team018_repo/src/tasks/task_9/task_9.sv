`timescale 1ns / 1ps

module task_9
#(
  parameter int TASK_INPUT_WIDTH  = 32,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input wire                          i_clk,
  input wire                          i_rst,

  input wire                          i_valid,
  input wire                          i_first,
  input wire                          i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data,

  output logic                         o_valid,
  output logic                         o_first,
  output logic                         o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  localparam int MAX_INPUT_SAMPLES = 2048;

  typedef enum logic [2:0] {
    ST_WAIT_CONFIG,
    ST_RECEIVE,
    ST_CALC_INIT,
    ST_CALCULATE,
    ST_NORMALIZE,
    ST_OUTPUT_CONFIG,
    ST_OUTPUT_DATA
  } state_t;

  state_t state, next_state;

  logic [31:0] sample_mem [0:MAX_INPUT_SAMPLES-1];
  logic [7:0] num_pair, num_rows, num_col_a, num_col_b;
  logic [5:0] row_blocks, col_a_blocks, col_b_blocks;
  logic [11:0] samples_per_pair, input_samples, receive_count;
  logic [7:0] pair_index;
  logic [5:0] out_col_index, out_row_index, row_block_index;
  logic [11:0] pair_base;

  logic signed [55:0] sum_00, sum_01, sum_10, sum_11;
  logic [3:0] result_exp;

  logic [31:0] a_sample, b_sample;
  logic signed [6:0] a_00, a_01, a_10, a_11;
  logic signed [6:0] b_00, b_01, b_10, b_11;
  logic [3:0] a_exp, b_exp;
  logic [4:0] product_exp;
  logic signed [55:0] term_00, term_01, term_10, term_11;
  logic signed [55:0] normalized_00, normalized_01;
  logic signed [55:0] normalized_10, normalized_11;
  logic [5:0] normalize_shift;

  function automatic logic signed [55:0] scaled_product;
    input logic signed [6:0] left_mantissa;
    input logic signed [6:0] right_mantissa;
    input logic [4:0] exponent;
    logic signed [13:0] product;
    begin
      product = left_mantissa * right_mantissa;
      scaled_product = {{42{product[13]}}, product} <<< exponent;
    end
  endfunction

  function automatic logic [5:0] value_normalize_shift;
    input logic signed [55:0] value;
    logic [55:0] magnitude;
    integer bit_index;
    begin
      if (value < 0)
        magnitude = -value - 1'b1;
      else
        magnitude = value;

      value_normalize_shift = '0;
      for (bit_index = 55; bit_index >= 6; bit_index = bit_index - 1) begin
        if ((value_normalize_shift == '0) && magnitude[bit_index])
          value_normalize_shift = bit_index - 5;
      end
    end
  endfunction

  function automatic logic [11:0] samples_in_packet;
    input logic [7:0] pairs;
    input logic [6:0] rows_2x2;
    input logic [6:0] cols_a_2x2;
    input logic [6:0] cols_b_2x2;
    integer samples_per_cracovian_pair;
    begin
      samples_per_cracovian_pair = rows_2x2 * (cols_a_2x2 + cols_b_2x2);
      samples_in_packet = pairs * samples_per_cracovian_pair;
    end
  endfunction

  always_ff @(posedge i_clk) begin
    if (i_rst)
      state <= ST_WAIT_CONFIG;
    else
      state <= next_state;
  end

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      num_pair         <= '0;
      num_rows         <= '0;
      num_col_a        <= '0;
      num_col_b        <= '0;
      row_blocks       <= '0;
      col_a_blocks     <= '0;
      col_b_blocks     <= '0;
      samples_per_pair <= '0;
      input_samples    <= '0;
      receive_count    <= '0;
      pair_index       <= '0;
      out_col_index    <= '0;
      out_row_index    <= '0;
      row_block_index  <= '0;
      pair_base        <= '0;
      sum_00           <= '0;
      sum_01           <= '0;
      sum_10           <= '0;
      sum_11           <= '0;
      result_exp       <= '0;
    end else begin
      case (state)
        ST_WAIT_CONFIG: begin
          if (i_valid && i_first) begin
            num_pair         <= i_data[31:24];
            num_rows         <= i_data[23:16];
            num_col_a        <= i_data[15:8];
            num_col_b        <= i_data[7:0];
            row_blocks       <= i_data[23:17];
            col_a_blocks     <= i_data[15:9];
            col_b_blocks     <= i_data[7:1];
            samples_per_pair <= samples_in_packet(8'd1, i_data[23:17],
                                                  i_data[15:9], i_data[7:1]);
            input_samples    <= samples_in_packet(i_data[31:24], i_data[23:17],
                                                  i_data[15:9], i_data[7:1]);
            receive_count    <= '0;
          end
        end

        ST_RECEIVE: begin
          if (i_valid) begin
            sample_mem[receive_count] <= i_data;
            receive_count <= receive_count + 1'b1;
          end
        end

        ST_CALC_INIT: begin
          pair_index      <= '0;
          out_col_index   <= '0;
          out_row_index   <= '0;
          row_block_index <= '0;
          pair_base       <= '0;
          sum_00          <= '0;
          sum_01          <= '0;
          sum_10          <= '0;
          sum_11          <= '0;
        end

        ST_CALCULATE: begin
          sum_00 <= sum_00 + term_00;
          sum_01 <= sum_01 + term_01;
          sum_10 <= sum_10 + term_10;
          sum_11 <= sum_11 + term_11;
          if (row_block_index == row_blocks - 1'b1)
            row_block_index <= '0;
          else
            row_block_index <= row_block_index + 1'b1;
        end

        ST_NORMALIZE: begin
          result_exp <= normalize_shift[3:0];
          sum_00 <= normalized_00;
          sum_01 <= normalized_01;
          sum_10 <= normalized_10;
          sum_11 <= normalized_11;
        end

        ST_OUTPUT_DATA: begin
          sum_00 <= '0;
          sum_01 <= '0;
          sum_10 <= '0;
          sum_11 <= '0;
          if (out_row_index == col_b_blocks - 1'b1) begin
            out_row_index <= '0;
            if (out_col_index == col_a_blocks - 1'b1) begin
              out_col_index <= '0;
              if (pair_index != num_pair - 1'b1) begin
                pair_index <= pair_index + 1'b1;
                pair_base  <= pair_base + samples_per_pair;
              end
            end else begin
              out_col_index <= out_col_index + 1'b1;
            end
          end else begin
            out_row_index <= out_row_index + 1'b1;
          end
        end
      endcase
    end
  end

  always_comb begin
    a_sample = sample_mem[pair_base + out_col_index * row_blocks + row_block_index];
    b_sample = sample_mem[pair_base + col_a_blocks * row_blocks +
                          out_row_index * row_blocks + row_block_index];

    a_11 = a_sample[31:25];
    a_10 = a_sample[24:18];
    a_01 = a_sample[17:11];
    a_00 = a_sample[10:4];
    a_exp = a_sample[3:0];
    b_11 = b_sample[31:25];
    b_10 = b_sample[24:18];
    b_01 = b_sample[17:11];
    b_00 = b_sample[10:4];
    b_exp = b_sample[3:0];
    product_exp = {1'b0, a_exp} + {1'b0, b_exp};

    term_00 = scaled_product(a_00, b_00, product_exp) +
              scaled_product(a_10, b_10, product_exp);
    term_01 = scaled_product(a_01, b_00, product_exp) +
              scaled_product(a_11, b_10, product_exp);
    term_10 = scaled_product(a_00, b_01, product_exp) +
              scaled_product(a_10, b_11, product_exp);
    term_11 = scaled_product(a_01, b_01, product_exp) +
              scaled_product(a_11, b_11, product_exp);

    normalize_shift = value_normalize_shift(sum_00);
    if (value_normalize_shift(sum_01) > normalize_shift)
      normalize_shift = value_normalize_shift(sum_01);
    if (value_normalize_shift(sum_10) > normalize_shift)
      normalize_shift = value_normalize_shift(sum_10);
    if (value_normalize_shift(sum_11) > normalize_shift)
      normalize_shift = value_normalize_shift(sum_11);
    normalized_00 = sum_00 >>> normalize_shift;
    normalized_01 = sum_01 >>> normalize_shift;
    normalized_10 = sum_10 >>> normalize_shift;
    normalized_11 = sum_11 >>> normalize_shift;
  end

  always_comb begin
    next_state = state;
    o_valid = 1'b0;
    o_first = 1'b0;
    o_last = 1'b0;
    o_data = '0;

    case (state)
      ST_WAIT_CONFIG: begin
        if (i_valid && i_first) begin
          if (i_last)
            next_state = ST_CALC_INIT;
          else
            next_state = ST_RECEIVE;
        end
      end

      ST_RECEIVE: begin
        if (i_valid && (i_last || (receive_count == input_samples - 1'b1)))
          next_state = ST_CALC_INIT;
      end

      ST_CALC_INIT: next_state = ST_CALCULATE;

      ST_CALCULATE: begin
        if (row_block_index == row_blocks - 1'b1)
          next_state = ST_NORMALIZE;
      end

      ST_NORMALIZE: begin
        if ((pair_index == '0) && (out_col_index == '0) && (out_row_index == '0))
          next_state = ST_OUTPUT_CONFIG;
        else
          next_state = ST_OUTPUT_DATA;
      end

      ST_OUTPUT_CONFIG: begin
        o_valid = 1'b1;
        o_first = 1'b1;
        o_data = {num_pair, num_col_b, 8'd0, num_col_a};
        next_state = ST_OUTPUT_DATA;
      end

      ST_OUTPUT_DATA: begin
        o_valid = 1'b1;
        o_data = {sum_11[6:0], sum_10[6:0], sum_01[6:0], sum_00[6:0], result_exp};
        o_last = (pair_index == num_pair - 1'b1) &&
                 (out_col_index == col_a_blocks - 1'b1) &&
                 (out_row_index == col_b_blocks - 1'b1);
        if (o_last)
          next_state = ST_WAIT_CONFIG;
        else begin
          next_state = ST_CALCULATE;
        end
      end

      default: next_state = ST_WAIT_CONFIG;
    endcase
  end
  
endmodule
