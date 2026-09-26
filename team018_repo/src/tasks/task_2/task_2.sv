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

  logic [TASK_INPUT_WIDTH-1:0] r_data0; // Just a dummy register. Replace with your code.
  logic [TASK_INPUT_WIDTH-1:0] r_data1; // Just a dummy register. Replace with your code.
  logic r_valid; // Just a dummy register. Replace with your code.
  logic r_last; // Just a dummy register. Replace with your code.

  always@(posedge i_clk) begin
    r_data0 <= i_data0; // Just a dummy assignement. Replace with your code.
    r_data1 <= i_data1; // Just a dummy assignement. Replace with your code.
    r_valid <= i_valid; // Just a dummy assignement. Replace with your code.
    r_last <= i_last; // Just a dummy assignement. Replace with your code.
  end

  assign o_data[TASK_OUTPUT_WIDTH/2-1:0] = r_data0; // Just a dummy assignement. Replace with your code.
  assign o_data[TASK_OUTPUT_WIDTH-1:TASK_OUTPUT_WIDTH/2] = r_data1; // Just a dummy assignement. Replace with your code.
  assign o_valid = r_valid; // Just a dummy assignement. Replace with your code.
  assign o_last = r_last; // Just a dummy assignement. Replace with your code.

endmodule
