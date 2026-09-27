// Managing AXI stream signals and deteccion of end -of-package

`timescale 1ns / 1ps

module handshake_control (
    input  logic       i_clk,
    input  logic       i_rst,

    // Upstream AXI
    input  logic       i_valid,
    output logic       i_ready,
    input  logic       i_last,

    // Downstream AXI
    output logic       o_valid,
    input  logic       o_ready,
    output logic       o_last,

    // Interfaz con Datapath
    input  logic [3:0] i_byte_cnt,
    output logic       o_in_fire,
    output logic       o_out_fire,
    output logic       o_pkt_ending
);

    logic pkt_ending_reg;

    // The 8-byte buffer can also accept a beat when a full output beat
    // leaves on this edge. This removes avoidable stalls at counts 5..8.
    // Deliberate tradeoff: downstream ready now feeds upstream ready.
    assign i_ready      = !i_rst && (!pkt_ending_reg) &&
                          ((i_byte_cnt <= 4'd4) || (o_valid && o_ready));
    assign o_valid      = (i_byte_cnt >= 4'd4) || (pkt_ending_reg && i_byte_cnt > 4'd0);
    assign o_last       = pkt_ending_reg && (i_byte_cnt <= 4'd4);

    assign o_in_fire    = i_valid && i_ready;
    assign o_out_fire   = o_valid && o_ready;
    assign o_pkt_ending = pkt_ending_reg;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            pkt_ending_reg <= 1'b0;
        end else begin
            if (o_in_fire && i_last) begin
                pkt_ending_reg <= 1'b1;
            end else if (o_out_fire && o_last) begin
                pkt_ending_reg <= 1'b0;
            end
        end
    end

endmodule
