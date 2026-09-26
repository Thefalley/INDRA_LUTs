`timescale 1ns / 1ps
module task_5 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8,
    parameter int NUM_OF_ROTORS     = 2,
    parameter int MAX_MSG_LENGTH    = 1024,
    parameter int ALPHABET_SIZE     = 128
) (
    input wire                        i_clk,
    input wire                        i_rst,

    input wire                        i_valid,
    input wire                        i_first,
    input wire                        i_last,
    input wire [TASK_INPUT_WIDTH-1:0] i_data,

    output logic                         o_valid,
    output logic                         o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);


    logic [TASK_OUTPUT_WIDTH-1:0] r_data; // Just a dummy register. Replace with your code.
    logic r_valid; // Just a dummy register. Replace with your code.
    logic r_last; // Just a dummy register. Replace with your code.

    always@(posedge i_clk) begin
        r_data <= i_data; // Just a dummy assignment. Replace with your code.
        r_valid <= i_valid; // Just a dummy assignment. Replace with your code.
        r_last <= i_last; // Just a dummy assignment. Replace with your code.
    end

    assign o_data = r_data; // Just a dummy assignment. Replace with your code.
    assign o_valid = r_valid; // Just a dummy assignment. Replace with your code.
    assign o_last = r_last; // Just a dummy assignment. Replace with your code.

endmodule
