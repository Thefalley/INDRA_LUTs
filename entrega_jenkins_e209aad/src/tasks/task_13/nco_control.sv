`timescale 1ns / 1ps

module nco_control (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic        i_valid,
    input  logic        i_first,
    input  logic        i_last,
    input  logic [15:0] i_data,

    output logic        o_valid,
    output logic        o_last,
    output logic [15:0] o_n_periods,
    output logic [15:0] o_wave_shape,
    output logic        o_gen_active,
    output logic [11:0] o_sample_cnt
);

    typedef enum logic [1:0] {
        ST_IDLE     = 2'b00,
        ST_CFG_SHP  = 2'b01,
        ST_GENERATE = 2'b10
    } state_t;

    state_t state;
    logic [11:0] sample_cnt;

    assign o_sample_cnt = sample_cnt;
    assign o_gen_active = (state == ST_GENERATE);

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state        <= ST_IDLE;
            o_n_periods  <= 16'd0;
            o_wave_shape <= 16'd0;
            sample_cnt   <= 12'd0;
            o_valid      <= 1'b0;
            o_last       <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    o_valid <= 1'b0;
                    o_last  <= 1'b0;
                    if (i_valid && i_first) begin
                        o_n_periods <= i_data;
                        state       <= ST_CFG_SHP;
                    end
                end

                ST_CFG_SHP: begin
                    if (i_valid && i_last) begin
                        o_wave_shape <= i_data;
                        sample_cnt   <= 12'd0;
                        state        <= ST_GENERATE;
                    end
                end

                ST_GENERATE: begin
                    o_valid <= 1'b1;

                    if (sample_cnt == 12'd2047) begin
                        o_last <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        o_last     <= 1'b0;
                        sample_cnt <= sample_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
