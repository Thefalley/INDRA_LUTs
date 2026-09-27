`timescale 1ns / 1ps
module task_1
#(
  parameter int TASK_INPUT_WIDTH = 16,
  parameter int TASK_OUTPUT_WIDTH = 16,
  parameter int INPUT_STREAMS     = 1,
  parameter int OUTPUT_STREAMS    = 1

)(
  input                               i_clk,
  input                               i_rst,

  input                               i_valid,
  input                               i_first,
  input                               i_last,
  input signed [TASK_INPUT_WIDTH-1:0] i_data,

  output reg                          o_valid,
  output reg                          o_last,
  output reg signed [TASK_OUTPUT_WIDTH-1:0] o_data
);

  reg signed [TASK_INPUT_WIDTH-1:0] maximum;
  wire signed [TASK_INPUT_WIDTH-1:0] candidate;

  // i_first must initialise the maximum with the actual first sample:
  // a packet may contain only negative values.
  assign candidate = (i_first || (i_data > maximum)) ? i_data : maximum;

  always @(posedge i_clk) begin
    if (i_rst) begin
      maximum <= '0;
      o_data  <= '0;
      o_valid <= 1'b0;
      o_last  <= 1'b0;
    end else begin
      // Output control signals are one-clock pulses.
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      if (i_valid) begin
        maximum <= candidate;
        if (i_last) begin
          // candidate includes the final sample; maximum is the prior cycle.
          o_data  <= candidate;
          o_valid <= 1'b1;
          o_last  <= 1'b1;
        end
      end
    end
  end

endmodule
