`timescale 1ns / 1ps
module task_16
#(
  parameter int TASK_INPUT_WIDTH  = 32,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input wire                              i_clk,
  input wire                              i_rst,

  input wire                              i_valid,
  output logic                            i_ready,
  input wire                              i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]      i_data,
  input wire  [TASK_INPUT_WIDTH/8-1:0]    i_keep,

  input wire                              o_ready,
  output logic                            o_valid,
  output logic                            o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0]    o_data,
  output logic [TASK_OUTPUT_WIDTH/8-1:0]  o_keep
);

  // TODO: Implement AXI-Stream compressor here.
  // Input:  i_data (TASK_INPUT_WIDTH bits) + i_keep (TASK_INPUT_WIDTH/8 bits) per beat.
  // Output: o_data (TASK_OUTPUT_WIDTH bits) + o_keep (TASK_OUTPUT_WIDTH/8 bits) per beat.
  // Allowed i_keep patterns are left-justified only: 0001, 0011, 0111, 1111.
  // Pack valid bytes contiguously across beats, emit full beats (o_keep=1111)
  // and a final partial beat (with the corresponding o_keep) on i_last.

  logic [TASK_OUTPUT_WIDTH-1:0]   r_data;
  logic [TASK_OUTPUT_WIDTH/8-1:0] r_keep;
  logic                          r_valid;
  logic                          r_last;

  assign i_ready = o_ready;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      r_valid <= 1'b0;
    end else if (o_ready) begin
      r_data  <= i_data;
      r_keep  <= i_keep;
      r_valid <= i_valid;
      r_last  <= i_last;
    end
  end

  assign o_data  = r_data;
  assign o_keep  = r_keep;
  assign o_valid = r_valid;
  assign o_last  = r_last;

endmodule
