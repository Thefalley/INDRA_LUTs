`timescale 1ns / 1ps
module task_3 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8,
    parameter int INPUT_STREAMS     = 1,
    parameter int OUTPUT_STREAMS    = 1

) (
    input i_clk,
    input i_rst,

    input [TASK_INPUT_WIDTH-1:0] i_data,
    input i_valid,
    input i_first,
    input i_last,

    output logic [TASK_OUTPUT_WIDTH-1:0] o_data,
    output logic o_valid,
    output logic o_last
);

  localparam int MAX_MATCHES = 253;
  typedef enum logic [1:0] {PATTERN, BITSTREAM, SEND_COUNT, SEND_INDICES} state_t;

  logic [3:0] pattern_reg;
  logic [2:0] history;
  logic [10:0] bit_window;
  logic [7:0] match_indices [0:MAX_MATCHES-1];
  logic [8:0] bits_received;
  logic [7:0] match_count, output_index;
  state_t state;
  integer bit_position;
  integer matches_in_byte;

  assign bit_window = {history, i_data};

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      pattern_reg   <= 4'd0;
      history       <= 3'd0;
      bits_received <= 9'd0;
      match_count   <= 8'd0;
      output_index  <= 8'd0;
      state         <= PATTERN;
      o_data        <= '0;
      o_valid       <= 1'b0;
      o_last        <= 1'b0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        PATTERN: if (i_valid) begin
          pattern_reg   <= i_data[3:0];
          history       <= 3'd0;
          bits_received <= 9'd0;
          match_count   <= 8'd0;
          state         <= BITSTREAM;
        end

        BITSTREAM: if (i_valid) begin
          // Each byte produces eight 4-bit windows. The first three windows
          // are masked until enough input bits have arrived.
          matches_in_byte = 0;
          for (bit_position = 0; bit_position < 8; bit_position = bit_position + 1) begin
            if ((bits_received + bit_position >= 3) &&
                (bit_window[10-bit_position -: 4] == pattern_reg)) begin
              match_indices[match_count + matches_in_byte] <= bits_received + bit_position - 3;
              matches_in_byte = matches_in_byte + 1;
            end
          end
          match_count   <= match_count + matches_in_byte;
          history       <= i_data[2:0];
          bits_received <= bits_received + 9'd8;
          if (i_last) begin
            state        <= SEND_COUNT;
            output_index <= 8'd0;
          end
        end

        SEND_COUNT: begin
          o_data  <= match_count;
          o_valid <= 1'b1;
          if (match_count == 0) begin
            o_last <= 1'b1;
            state  <= PATTERN;
          end else begin
            state <= SEND_INDICES;
          end
        end

        SEND_INDICES: begin
          o_data  <= match_indices[output_index];
          o_valid <= 1'b1;
          if (output_index == match_count - 1'b1) begin
            o_last <= 1'b1;
            state  <= PATTERN;
          end else begin
            output_index <= output_index + 1'b1;
          end
        end
      endcase
    end
  end

endmodule
