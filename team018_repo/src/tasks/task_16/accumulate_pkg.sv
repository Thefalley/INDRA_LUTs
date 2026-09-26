// Datapath and accumulator
`timescale 1ns / 1ps

module accumulate_pkg #(
    parameter int DATA_WIDTH = 32
)(
    input  logic                  i_clk,
    input  logic                  i_rst,

    // Control Interno
    input  logic                  i_in_fire,
    input  logic                  i_out_fire,
    input  logic                  i_last_out,
    input  logic [2:0]            i_in_bytes,

    // Datos AXI
    input  logic [DATA_WIDTH-1:0] i_data,
    output logic [DATA_WIDTH-1:0] o_data,
    output logic [DATA_WIDTH/8-1:0] o_keep,
    output logic [3:0]            o_byte_cnt
);

    logic [63:0] shift_reg;
    logic [3:0]  byte_cnt;

    assign o_byte_cnt = byte_cnt;
    assign o_data     = shift_reg[DATA_WIDTH-1:0];

    // Decodificación dinámica de o_keep para la salida
    always_comb begin
        if (byte_cnt >= 4'd4) begin
            o_keep = 4'hF;
        end else begin
            case (byte_cnt[1:0])
                2'd1:    o_keep = 4'h1;
                2'd2:    o_keep = 4'h3;
                2'd3:    o_keep = 4'h7;
                default: o_keep = 4'hF;
            endcase
        end
    end

    // Registro Acumulador
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            byte_cnt  <= 4'd0;
            shift_reg <= 64'd0;
        end else begin
            // Consumo de datos hacia downstream
            if (i_out_fire) begin
                if (i_last_out) begin
                    byte_cnt  <= 4'd0;
                    shift_reg <= 64'd0;
                end else begin
                    shift_reg <= {32'h0, shift_reg[63:32]};
                    byte_cnt  <= byte_cnt - 4'd4;
                end
            end

            // Inserción de nuevos datos desde upstream
            if (i_in_fire) begin
                case (byte_cnt - (i_out_fire ? 4'd4 : 4'd0))
                    4'd0: shift_reg[31:0]  <= i_data;
                    4'd1: shift_reg[39:8]  <= i_data;
                    4'd2: shift_reg[47:16] <= i_data;
                    4'd3: shift_reg[55:24] <= i_data;
                    default: ;
                endcase

                byte_cnt <= (byte_cnt - (i_out_fire ? 4'd4 : 4'd0)) + i_in_bytes;
            end
        end
    end

endmodule