`timescale 1ns / 1ps
module task_2
#(
  parameter int TASK_INPUT_WIDTH  = 16,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input wire                          i_clk,
  input wire                          i_rst,

  input wire                          i_valid,
  input wire                          i_first,
  input wire                          i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data0,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data1,

  output logic                         o_valid,
  output logic                         o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  typedef enum logic [1:0] {
    ST_WAIT,
    ST_CAPTURE,
    ST_HEADER,
    ST_OUTPUT
  } state_t;

  state_t state, next_state;
  logic [15:0] sample_mem [0:2047];
  logic [11:0] sample_count;
  logic [11:0] output_count;
  logic signed [31:0] correction;
  logic signed [15:0] corrected_sample;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state <= ST_WAIT;
      sample_count <= '0;
      output_count <= '0;
    end else begin
      state <= next_state;
      case (state)
        ST_WAIT: begin
          sample_count <= '0;
          output_count <= '0;
          if (i_valid && i_first) begin
            sample_mem[0] <= corrected_sample;
            if (!i_last)
              sample_count <= 12'd1;
          end
        end

        ST_CAPTURE: begin
          if (i_valid) begin
            sample_mem[sample_count] <= corrected_sample;
            if (i_last) begin
              output_count <= '0;
            end else begin
              sample_count <= sample_count + 1'b1;
            end
          end
        end

        ST_OUTPUT: begin
          if (output_count != sample_count)
            output_count <= output_count + 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  always_comb begin
    correction = -32'sd1599 - ($signed(i_data0) <<< 6) - ($signed(i_data0) <<< 4) +
                 (($signed(i_data1) * 32'sd23) >>> 5);
    if (correction > 32'sd32767)
      corrected_sample = 16'sh7fff;
    else if (correction < -32'sd32768)
      corrected_sample = 16'sh8000;
    else
      corrected_sample = correction[15:0];
  end

  always_comb begin
    next_state = state;
    o_valid = 1'b0;
    o_last = 1'b0;
    o_data = '0;

    case (state)
      ST_WAIT: begin
        if (i_valid && i_first)
          next_state = i_last ? ST_HEADER : ST_CAPTURE;
      end

      ST_CAPTURE: begin
        if (i_valid && i_last)
          next_state = ST_HEADER;
      end

      ST_HEADER: begin
        o_valid = 1'b1;
        o_data = 32'h0100_7171;
        next_state = ST_OUTPUT;
      end

      ST_OUTPUT: begin
        o_valid = 1'b1;
        o_data = {{16{sample_mem[output_count][15]}}, sample_mem[output_count]};
        o_last = (output_count == sample_count);
        if (o_last)
          next_state = ST_WAIT;
      end

      default: next_state = ST_WAIT;
    endcase
  end

endmodule
