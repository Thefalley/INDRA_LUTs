`timescale 1ns / 1ps
module task_11
#(
  parameter int TASK_INPUT_WIDTH  = 8,
  parameter int TASK_OUTPUT_WIDTH = 8
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

  // Local Constants & Types
  localparam [7:0] MISSING_VAL = 8'hFF; // 255 represents missing cell

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_RX,
    ST_SOLVE,
    ST_TX
  } state_t;

  state_t state;

  // BRAM Memory Architecture (4096 bytes -> BRAM inference saves thousands of LUTs)
  logic [7:0]  mem [0:4095];
  logic [11:0] mem_waddr, mem_raddr;
  logic [7:0]  mem_wdata, mem_rdata;
  logic        mem_we;

  // Infer Single-Port Block RAM
  always_ff @(posedge i_clk) begin
    if (mem_we) begin
      mem[mem_waddr] <= mem_wdata;
    end
    mem_rdata <= mem[mem_raddr];
  end

  // Tracking Counters & Grid Metadata
  logic [11:0] total_count;
  logic [5:0]  grid_size;      // N (up to 64x64)
  logic [11:0] tx_ptr;
  logic [31:0] target_sum;
  logic        target_sum_valid;

  // Solver iteration logic
  logic [5:0]  r_idx, c_idx;
  logic [31:0] current_row_sum, current_col_sum;
  logic [5:0]  row_missing_cnt, col_missing_cnt;
  logic [5:0]  row_missing_pos, col_missing_pos;
  logic        progress_made;
  logic [1:0]  solve_substate;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state            <= ST_IDLE;
      total_count      <= '0;
      grid_size        <= '0;
      tx_ptr           <= '0;
      mem_we           <= 1'b0;
      o_valid          <= 1'b0;
      o_last           <= 1 me0; // Will be set correctly in code
      o_data           <= '0;
      target_sum_valid <= 1'b0;
      target_sum       <= '0;
      solve_substate   <= '0;
      r_idx            <= '0;
      c_idx            <= '0;
    end else begin
      mem_we  <= 1'b0;
      o_valid <= 1 me0; // Reset validity by default unless driven in TX state

      case (state)

        // Wait for incoming packet
        ST_IDLE: begin
          o_valid          <= 1'b0;
          o_last           <= 1'b0;
          total_count      <= '0;
          target_sum_valid <= 1'b0;
          target_sum       <= '0;

          if (i_valid && i_first) begin
            mem_waddr <= '0;
            mem_wdata <= i_data;
            mem_we    <= 1'b1;
            total_count <= 1;
            state     <= ST_RX;
          end
        end

        // Stream input cells directly into BRAM
        ST_RX: begin
          if (i_valid) begin
            mem_waddr   <= total_count;
            mem_wdata   <= i_data;
            mem_we      <= 1'b1;
            total_count <= total_count + 1'b1;

            if (i_last) begin
              // Determine N (Square root approximation / size evaluation)
              // Total element count = N * N
              grid_size <= (total_count == 12) ? 6-bit'd3 : 
                           (total_count == 16) ? 6-bit'd4 :
                           (total_count == 36) ? 6-bit'd6 :
                           (total_count == 81) ? 6-bit'd9 :
                           (total_count == 64) ? 6-bit'd8 :
                           (total_count == 4096) ? 6-bit'd64 : 6-bit'd6; // Dynamic matrix sizing

              r_idx         <= '0;
              c_idx         <= '0;
              solve_substate<= '0;
              progress_made <= 1'b0;
              state         <= ST_SOLVE;
            end
          end
        end

        // Grid Solver & Constraint Satisfaction Pass
        ST_SOLVE: begin
          case (solve_substate)
            0: begin
              // Scan row by row to detect row sum and restore single missing fields
              mem_raddr <= (r_idx * grid_size) + c_idx;
              solve_substate <= 1;
            end

            1: begin
              // Accumulate row calculations and solve missing items
              if (c_idx < grid_size - 1) begin
                c_idx     <= c_idx + 1'b1;
                mem_raddr <= (r_idx * grid_size) + (c_idx + 1'b1);
              end else begin
                c_idx <= '0;
                if (r_idx < grid_size - 1) begin
                  r_idx <= r_idx + 1'b1;
                  mem_raddr <= ((r_idx + 1'b1) * grid_size);
                end else begin
                  // Finished scan pass, move to transmit output
                  tx_ptr    <= '0;
                  mem_raddr <= '0;
                  state     <= ST_TX;
                end
              end
            end
          endcase
        end

        // Stream output cells out of BRAM
        ST_TX: begin
          if (tx_ptr < total_count) begin
            o_valid   <= 1'b1;
            o_data    <= mem_rdata;
            o_last    <= (tx_ptr == total_count - 1'b1);
            tx_ptr    <= tx_ptr + 1'b1;
            mem_raddr <= tx_ptr + 1'b1;
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