`timescale 1ns / 1ps

module wave_generator #(
    parameter int DATA_WIDTH = 16
)(
    input  logic [10:0]            i_phase,
    input  logic [10:0]            i_n_periods,
    input  logic [1:0]             i_wave_shape, // 01=Sin, 10=Tri, 11=Rect
    output logic [DATA_WIDTH-1:0]  o_data
);

    // 1. RECTÁNGULO (0 a 32767)
    wire [10:0] rect_p_len = (11'd2048 / i_n_periods);
    wire [10:0] rect_phase = i_phase % rect_p_len;
    wire [15:0] rect_wave  = (rect_phase < (rect_p_len >> 1)) ? 16'd32767 : 16'd0;

    // 2. TRIÁNGULO (0 a 32767)
    wire [10:0] tri_p_len  = (11'd2048 / i_n_periods);
    wire [10:0] tri_phase  = i_phase % tri_p_len;
    wire [10:0] tri_p_half = tri_p_len >> 1;

    logic [15:0] tri_wave;
    always_comb begin
        if (tri_phase < tri_p_half) begin
            tri_wave = (tri_phase == 0) ? 16'd0 : ((tri_phase * 16'd32767) / tri_p_half);
        end else begin
            tri_wave = (((tri_p_len - tri_phase) * 16'd32767) / tri_p_half);
        end
    end

    // 3. SENO (-32767 a 32767)
    logic signed [15:0] sin_wave;
    logic signed [15:0] quad_val;

    always_comb begin
        if (i_phase < 11'd1024) begin
            if (i_phase < 11'd512)
                quad_val = (i_phase * 16'd32767) / 11'd512;
            else
                quad_val = ((11'd1024 - i_phase) * 16'd32767) / 11'd512;
            sin_wave = quad_val;
        end else begin
            if (i_phase < 11'd1536)
                quad_val = ((i_phase - 11'd1024) * 16'd32767) / 11'd512;
            else
                quad_val = ((11'd2048 - i_phase) * 16'd32767) / 11'd512;
            sin_wave = -quad_val;
        end
    end

    // Multiplexor de forma de onda
    logic [15:0] wave_out;
    always_comb begin
        case (i_wave_shape)
            2'b01:   wave_out = sin_wave;
            2'b10:   wave_out = tri_wave;
            2'b11:   wave_out = rect_wave;
            default: wave_out = 16'd0;
        endcase
    end

    assign o_data = wave_out[DATA_WIDTH-1:0];

endmodule