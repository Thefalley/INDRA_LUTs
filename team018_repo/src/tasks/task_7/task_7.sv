`timescale 1ns / 1ps

// ==========================================
// Módulo CORDIC Vectorial en Q20.12
// Calcula: angle = atan2(y, x) y radius = sqrt(x^2 + y^2)
// ==========================================
module cordic_atan2 #(
    parameter int DATA_WIDTH = 32,
    parameter int FRAC_BITS  = 12
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          start,
    input  wire signed [DATA_WIDTH-1:0]  x_in,
    input  wire signed [DATA_WIDTH-1:0]  y_in,
    output logic signed [DATA_WIDTH-1:0] angle_out,
    output logic signed [DATA_WIDTH-1:0] radius_out,
    output logic                         done
);

    // Tabla LUT de atan(2^-i) escalada en Q20.12 (rad * 4096)
    localparam signed [31:0] ATAN_LUT [0:15] = '{
        32'sd3217, 32'sd1899, 32'sd1003, 32'sd510,
        32'sd256,  32'sd128,  32'sd64,   32'sd32,
        32'sd16,   32'sd8,    32'sd4,    32'sd2,
        32'sd1,    32'sd0,    32'sd0,    32'sd0
    };

    localparam signed [31:0] PI_Q20_12 = 32'sd12868; // pi * 4096

    logic [4:0] step;
    logic signed [DATA_WIDTH-1:0] x, y, z;

    always_ff @(posedge clk) begin
        if (rst) begin
            step       <= '0;
            done       <= 1'b0;
            angle_out  <= '0;
            radius_out <= '0;
            x          <= '0;
            y          <= '0;
            z          <= '0;
        end else if (start) begin
            step <= '0;
            done <= 1'b0;
            if (x_in >= 0) begin
                x <= x_in;
                y <= y_in;
                z <= 32'sd0;
            end else begin
                x <= -x_in;
                y <= -y_in;
                z <= (y_in >= 0) ? PI_Q20_12 : -PI_Q20_12;
            end
        end else if (step < 16 && !done) begin
            automatic logic signed [DATA_WIDTH-1:0] x_shift = x >>> step;
            automatic logic signed [DATA_WIDTH-1:0] y_shift = y >>> step;

            if (y < 0) begin
                x <= x - y_shift;
                y <= y + x_shift;
                z <= z - ATAN_LUT[step];
            end else begin
                x <= x + y_shift;
                y <= y - x_shift;
                z <= z + ATAN_LUT[step];
            end
            step <= step + 1'b1;
        end else if (step == 16) begin
            angle_out  <= z;
            // Ajuste por la ganancia CORDIC K ~ 1.64676 (factor 0.607252 en Q20.12 = 2487)
            radius_out <= (x * 32'sd2487) >>> FRAC_BITS;
            done       <= 1'b1;
        end
    end
endmodule

// ==========================================
// Módulo Principal: Task 7
// ==========================================
module task_7 #(
    parameter int TASK_INPUT_WIDTH  = 32,
    parameter int TASK_OUTPUT_WIDTH = 32
)(
    input wire                           i_clk,
    input wire                           i_rst,

    input wire                           i_valid,
    input wire                           i_first,
    input wire                           i_last,
    input wire  [TASK_INPUT_WIDTH-1:0]   i_data,

    output logic                         o_valid,
    output logic                         o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    logic [31:0] headers [0:2];
    logic signed [31:0] x_pos   [0:2];
    logic signed [31:0] y_pos   [0:2];
    logic signed [31:0] z_pos   [0:2];
    logic signed [31:0] r33_val [0:2];

    logic [31:0] phi1_out [0:2];
    logic [31:0] phi2_out [0:2];
    logic [31:0] phi3_out [0:2];
    logic [31:0] phi4_out [0:2];

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RECEIVE,
        ST_SOLVE_IK,
        ST_TRANSMIT
    } state_t;

    state_t state;

    integer rx_word_cnt;
    integer calc_idx;
    integer tx_word_cnt;

    // Constantes en formato Q20.12
    localparam signed [31:0] D0_Q20_12 = 32'sd740;   // d0 = 0.18070
    localparam signed [31:0] A2_Q20_12 = -32'sd2510; // a2 = -0.61270
    localparam signed [31:0] A3_Q20_12 = -32'sd2341; // a3 = -0.57155
    localparam signed [31:0] D4_Q20_12 = 32'sd713;   // d4 = 0.17415
    localparam signed [31:0] D5_Q20_12 = 32'sd491;   // d5 = 0.11985

    // Señales para instancia CORDIC
    logic cordic_start;
    logic cordic_done;
    logic signed [31:0] cordic_x, cordic_y, cordic_angle, cordic_radius;

    cordic_atan2 #(
        .DATA_WIDTH(32),
        .FRAC_BITS(12)
    ) u_cordic (
        .clk(i_clk),
        .rst(i_rst),
        .start(cordic_start),
        .x_in(cordic_x),
        .y_in(cordic_y),
        .angle_out(cordic_angle),
        .radius_out(cordic_radius),
        .done(cordic_done)
    );

    // Sub-estados para resolver la IK punto a punto con CORDIC
    typedef enum logic [2:0] {
        IK_INIT_PHI1,
        IK_WAIT_PHI1,
        IK_COMPUTE_ARM,
        IK_NEXT_POINT
    } ik_substate_t;

    ik_substate_t ik_state;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state        <= ST_IDLE;
            ik_state     <= IK_INIT_PHI1;
            rx_word_cnt  <= 0;
            calc_idx     <= 0;
            tx_word_cnt  <= 0;
            o_valid      <= 1'b0;
            o_last       <= 1 meb0;
            o_data       <= '0;
            cordic_start <= 1'b0;
            cordic_x     <= '0;
            cordic_y     <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    o_valid     <= 1'b0;
                    o_last      <= 1'b0;
                    rx_word_cnt <= 0;

                    if (i_valid && i_first) begin
                        headers[0]  <= i_data;
                        rx_word_cnt <= 1;
                        state       <= ST_RECEIVE;
                    end
                end

                ST_RECEIVE: begin
                    if (i_valid) begin
                        case (rx_word_cnt)
                            1:  x_pos[0]   <= i_data;
                            2:  y_pos[0]   <= i_data;
                            3:  z_pos[0]   <= i_data;
                            4:  r33_val[0] <= i_data;

                            5:  headers[1] <= i_data;
                            6:  x_pos[1]   <= i_data;
                            7:  y_pos[1]   <= i_data;
                            8:  z_pos[1]   <= i_data;
                            9:  r33_val[1] <= i_data;

                            10: headers[2] <= i_data;
                            11: x_pos[2]   <= i_data;
                            12: y_pos[2]   <= i_data;
                            13: z_pos[2]   <= i_data;
                            14: r33_val[2] <= i_data;
                            default: ;
                        endcase

                        rx_word_cnt <= rx_word_cnt + 1;

                        if (i_last) begin
                            calc_idx <= 0;
                            ik_state <= IK_INIT_PHI1;
                            state    <= ST_SOLVE_IK;
                        end
                    end
                end

                ST_SOLVE_IK: begin
                    case (ik_state)
                        IK_INIT_PHI1: begin
                            cordic_x     <= x_pos[calc_idx];
                            cordic_y     <= y_pos[calc_idx];
                            cordic_start <= 1'b1;
                            ik_state     <= IK_WAIT_PHI1;
                        end

                        IK_WAIT_PHI1: begin
                            cordic_start <= 1'b0;
                            if (cordic_done) begin
                                phi1_out[calc_idx] <= cordic_angle; // phi1 = atan2(y, x)
                                ik_state           <= IK_COMPUTE_ARM;
                            end
                        end

                        IK_COMPUTE_ARM: begin
                            automatic logic signed [31:0] z_prime;
                            automatic logic signed [31:0] r_proj;

                            z_prime = z_pos[calc_idx] - D0_Q20_12;
                            r_proj  = cordic_radius;

                            // Geometría analítica en Q20.12
                            phi2_out[calc_idx] <= z_prime - A2_Q20_12;
                            phi3_out[calc_idx] <= r_proj + A3_Q20_12;
                            phi4_out[calc_idx] <= r33_val[calc_idx] - D4_Q20_12 - D5_Q20_12;

                            ik_state <= IK_NEXT_POINT;
                        end

                        IK_NEXT_POINT: begin
                            if (calc_idx < 2) begin
                                calc_idx <= calc_idx + 1;
                                ik_state <= IK_INIT_PHI1;
                            end else begin
                                tx_word_cnt <= 0;
                                state       <= ST_TRANSMIT;
                            end
                        end
                    endcase
                end

                ST_TRANSMIT: begin
                    if (tx_word_cnt < 15) begin
                        o_valid <= 1'b1;

                        case (tx_word_cnt)
                            0:  o_data <= headers[0];
                            1:  o_data <= phi1_out[0];
                            2:  o_data <= phi2_out[0];
                            3:  o_data <= phi3_out[0];
                            4:  o_data <= phi4_out[0];

                            5:  o_data <= headers[1];
                            6:  o_data <= phi1_out[1];
                            7:  o_data <= phi2_out[1];
                            8:  o_data <= phi3_out[1];
                            9:  o_data <= phi4_out[1];

                            10: o_data <= headers[2];
                            11: o_data <= phi1_out[2];
                            12: o_data <= phi2_out[2];
                            13: o_data <= phi3_out[2];
                            14: o_data <= phi4_out[2];
                            default: o_data <= '0;
                        endcase

                        o_last      <= (tx_word_cnt == 14);
                        tx_word_cnt <= tx_word_cnt + 1;
                    end else begin
                        o_valid <= 1'b0;
                        o_last  <= 1'b0;
                        state   <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule