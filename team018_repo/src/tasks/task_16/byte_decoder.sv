// Combinational module to reduce i_keep patterns into valid bytes (1 up to 4)
`timescale 1ns / 1ps

module byte_decoder #(
    parameter int BYTE_DECODER_WIDTH = 4
)(
    input  logic [BYTE_DECODER_WIDTH-1:0] i_keep,
    output logic [2:0]            o_bytes
);
    always_comb begin
        case (i_keep)
            4'b0001: o_bytes = 3'd1;
            4'b0011: o_bytes = 3'd2;
            4'b0111: o_bytes = 3'd3;
            4'b1111: o_bytes = 3'd4;
            default: o_bytes = 3'd0;
        endcase
    end
endmodule