`timescale 1ns/1ps
// Experimental only: input and radius Q12, XY internal Q32, angle Q30 radians.
// Separate explicit output in Q12 degrees. Not a robot IK solver.
module cordic_precise #(parameter integer ITERATIONS=24)(
 input wire clk,rst,start,
 input wire signed [31:0] x_in,y_in,
 output logic signed [47:0] angle_rad_q30,
 output logic signed [31:0] angle_deg_q12,radius_q12,
 output logic done
);
 localparam logic signed [47:0] PI_Q30=48'sd3373259426;
 localparam logic signed [47:0] ATAN_Q30[0:23]='{
 48'sd843314857,48'sd497837829,48'sd263043837,48'sd133525159,
 48'sd67021687,48'sd33543516,48'sd16775851,48'sd8388437,
 48'sd4194283,48'sd2097149,48'sd1048576,48'sd524288,
 48'sd262144,48'sd131072,48'sd65536,48'sd32768,
 48'sd16384,48'sd8192,48'sd4096,48'sd2048,
 48'sd1024,48'sd512,48'sd256,48'sd128};
 logic signed [63:0] x,y;
 logic signed [47:0] z;
 wire signed [63:0] input_x_ext={{32{x_in[31]}},x_in};
 wire signed [63:0] input_y_ext={{32{y_in[31]}},y_in};
 wire signed [95:0] radius_product=x*32'sd652032874;
 wire signed [79:0] degree_product=z*32'sd60078979;
 logic busy,zero_vector;
 integer step;
 always_ff @(posedge clk) begin
  if(rst) begin
   busy<=0;done<=0;step<=0;x<=0;y<=0;z<=0;zero_vector<=0;
   angle_rad_q30<=0;angle_deg_q12<=0;radius_q12<=0;
  end else begin
   done<=0;
   if(start && !busy) begin
    busy<=1;step<=0;zero_vector<=(x_in==0 && y_in==0);
    if(x_in<0) begin
     x<=-(input_x_ext<<<20);y<=-(input_y_ext<<<20);
     z<=(y_in>=0)?PI_Q30:-PI_Q30;
    end else begin x<=input_x_ext<<<20;y<=input_y_ext<<<20;z<=0;end
   end else if(busy && step<ITERATIONS) begin
    if(y<0) begin x<=x-(y>>>step);y<=y+(x>>>step);z<=z-ATAN_Q30[step];end
    else begin x<=x+(y>>>step);y<=y-(x>>>step);z<=z+ATAN_Q30[step];end
    step<=step+1;
   end else if(busy) begin
    // Round magnitudes symmetrically. Conversion: Q30*Q20 -> degrees Q12.
    angle_rad_q30<=zero_vector?48'sd0:z;
    if(zero_vector) begin angle_deg_q12<=0;radius_q12<=0;end
    else begin
     if(degree_product>=0) angle_deg_q12<=(degree_product+(80'sd1<<<37))>>>38;
     else angle_deg_q12<=-(((-degree_product)+(80'sd1<<<37))>>>38);
     radius_q12<=(radius_product+(96'sd1<<<49))>>>50;
    end
    busy<=0;done<=1;
   end
  end
 end
endmodule

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

    // SeÃƒÂ±ales para instancia CORDIC
    logic cordic_start;
    logic cordic_done;
    logic signed [31:0] cordic_x, cordic_y, cordic_angle, cordic_radius;

    cordic_precise #(.ITERATIONS(24)) u_cordic (
        .clk(i_clk),
        .rst(i_rst),
        .start(cordic_start),
        .x_in(cordic_x),
        .y_in(cordic_y),
        .angle_rad_q30(),
        .angle_deg_q12(cordic_angle),
        .radius_q12(cordic_radius),
        .done(cordic_done)
    );

    // Sub-estados para resolver la IK punto a punto con CORDIC
    typedef enum logic [2:0] {
        IK_INIT_PHI1,
        IK_START_PHI1,
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
            o_last       <= 1'b0;
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
                            ik_state     <= IK_START_PHI1;
                        end

                        IK_START_PHI1: begin
                            cordic_start <= 1'b0;
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

                            // GeometrÃƒÂ­a analÃƒÂ­tica en Q20.12
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
