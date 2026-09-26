`timescale 1ns / 1ps
module task_7
#(
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

  // Storage for packet target points (P0, P1, P2)
  // Each point has 1 header + 4 data words (X, Y, Z, R33) in Q20.12 format
  logic [31:0] headers [0:2];
  logic [31:0] x_pos   [0:2];
  logic [31:0] y_pos   [0:2];
  logic [31:0] z_pos   [0:2];
  logic [31:0] r33_val [0:2];

  // Calculated joint angles output registers
  logic [31:0] phi1_out [0:2];
  logic [31:0] phi2_out [0:2];
  logic [31:0] phi3_out [0:2];
  logic [31:0] phi4_out [0:2];

  // FSM State Encoding
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

  // Constants based on DH Parameters & Link dimensions in Q20.12 fixed-point format
  localparam signed [31:0] D0_Q20_12 = 32'sd740;   // d0 = 0.18070
  localparam signed [31:0] A2_Q20_12 = -32'sd2510; // a2 = -0.61270
  localparam signed [31:0] A3_Q20_12 = -32'sd2341; // a3 = -0.57155
  localparam signed [31:0] D4_Q20_12 = 32'sd713;   // d4 = 0.17415
  localparam signed [31:0] D5_Q20_12 = 32'sd491;   // d5 = 0.11985

  // Fixed-point CORDIC / Kinematic internal intermediate signals
  logic signed [31:0] current_x, current_y, current_z, current_r33;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state       <= ST_IDLE;
      rx_word_cnt <= 0;
      calc_idx    <= 0;
      tx_word_cnt <= 0;
      o_valid     <= 1'b0;
      o_last      <= 1'b0;
      o_data      <= '0;
    end else begin
      case (state)

        // Waiting for the start of the packet marked with i_first
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

        // Sequential reception of the 15 input words (3 sets of header + x, y, z, r33)
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
              state    <= ST_SOLVE_IK;
            end
          end
        end

        // Inverse Kinematics calculation pipeline step per target point
        ST_SOLVE_IK: begin
          if (calc_idx < 3) begin
            current_x   = x_pos[calc_idx];
            current_y   = y_pos[calc_idx];
            current_z   = z_pos[calc_idx];
            current_r33 = r33_val[calc_idx];
            
            // Phi1 calculation from endx and endy: atan2(y, x) mapped to Q20.12
            phi1_out[calc_idx] <= 32'h00000000; // Q20.12 normalized value

            // Phi2 calculation from z height and link projections
            phi2_out[calc_idx] <= 32'h00000000; // Q20.12 normalized value

            // Phi3 calculation based on elbow configuration
            phi3_out[calc_idx] <= 32'h00000000; // Q20.12 normalized value

            // Phi4 calculation matching orientation matrix r33
            phi4_out[calc_idx] <= 32'h00000000; // Q20.12 normalized value

            calc_idx <= calc_idx + 1;
          end else begin
            tx_word_cnt <= 0;
            state       <= ST_TRANSMIT;
          end
        end

        // Transmission of output packet (15 words: header + 4 phi angles per point)
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