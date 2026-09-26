`timescale 1ns / 1ps

module phase_accumulator (
    input  logic        i_clk,
    input  logic        i_rst,
    input  logic        i_gen_active,
    input  logic [10:0] i_n_periods,
    output logic [10:0] o_phase
);

    logic [10:0] phase_acc;

    assign o_phase = phase_acc;

    always_ff @(posedge i_clk) begin
        if (i_rst || !i_gen_active) begin
            phase_acc <= 11'd0;
        end else begin
            phase_acc <= phase_acc + i_n_periods;
        end
    end

endmodule