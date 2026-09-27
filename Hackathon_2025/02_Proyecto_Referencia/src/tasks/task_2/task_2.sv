`timescale 1ns / 1ps
module task_2
#(
  parameter int TASK_INPUT_WIDTH = 8,
  parameter int TASK_OUTPUT_WIDTH = 8,
  parameter int INPUT_STREAMS     = 1,
  parameter int OUTPUT_STREAMS    = 1

)(
  input                         i_clk,
  input                         i_rst,

  input                         i_valid,
  input                         i_first,
  input                         i_last,
  input [TASK_INPUT_WIDTH-1:0]  i_data,

  output logic                  o_valid,
  output logic                  o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  localparam int MAX_CELLS = 4090;
  typedef enum logic [1:0] {RECEIVE, SEND} state_t;

  logic [TASK_INPUT_WIDTH-1:0] matrix [0:MAX_CELLS-1];
  logic [1:0] header_count;
  logic [7:0] columns, rows;
  logic [11:0] write_address;
  logic [12:0] total_cells, sent_cells;
  logic [8:0] diagonal;
  logic [8:0] row, column;
  logic [12:0] read_address;
  state_t state;

  // Extend both factors before multiplication. A 9-bit product would wrap at
  // address 512 although the matrix may contain up to 4090 cells.
  assign read_address = {4'd0, row} * {5'd0, columns} + column;

  function automatic [8:0] diagonal_first_row(input logic [8:0] d);
    begin
      diagonal_first_row = (d >= columns) ? (d - columns + 1'b1) : 9'd0;
    end
  endfunction

  function automatic [8:0] diagonal_last_row(input logic [8:0] d);
    begin
      diagonal_last_row = (d >= rows) ? (rows - 1'b1) : d;
    end
  endfunction

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      header_count <= 2'd0;
      columns      <= 8'd0;
      rows         <= 8'd0;
      write_address <= 12'd0;
      total_cells  <= 13'd0;
      sent_cells   <= 13'd0;
      diagonal     <= 9'd0;
      row          <= 9'd0;
      column       <= 9'd0;
      state        <= RECEIVE;
      o_data       <= '0;
      o_valid      <= 1'b0;
      o_last       <= 1'b0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        RECEIVE: if (i_valid) begin
          case (header_count)
            2'd0: begin
              // Header order is x then y: columns, then rows.
              columns      <= i_data;
              header_count <= 2'd1;
            end
            2'd1: begin
              rows          <= i_data;
              total_cells   <= columns * i_data;
              write_address <= 12'd0;
              header_count  <= 2'd2;
            end
            default: begin
              matrix[write_address] <= i_data;
              write_address <= write_address + 1'b1;
              if (i_last) begin
                // Output begins on the following clock, after the last RAM write.
                state      <= SEND;
                sent_cells <= 13'd0;
                diagonal   <= 9'd0;
                row        <= 9'd0;
                column     <= 9'd0;
              end
            end
          endcase
        end

        SEND: begin
          o_data  <= matrix[read_address];
          o_valid <= 1'b1;

          if (sent_cells == total_cells - 1'b1) begin
            o_last       <= 1'b1;
            state        <= RECEIVE;
            header_count <= 2'd0;
          end else begin
            sent_cells <= sent_cells + 1'b1;

            if (!diagonal[0] && row > diagonal_first_row(diagonal)) begin
              // Even diagonal: bottom-left to top-right.
              row    <= row - 1'b1;
              column <= column + 1'b1;
            end else if (diagonal[0] && row < diagonal_last_row(diagonal)) begin
              // Odd diagonal: top-right to bottom-left.
              row    <= row + 1'b1;
              column <= column - 1'b1;
            end else begin
              diagonal <= diagonal + 1'b1;
              if (diagonal[0]) begin
                // The next diagonal is even and begins at its last row.
                row    <= diagonal_last_row(diagonal + 1'b1);
                column <= diagonal + 1'b1 - diagonal_last_row(diagonal + 1'b1);
              end else begin
                // The next diagonal is odd and begins at its first row.
                row    <= diagonal_first_row(diagonal + 1'b1);
                column <= diagonal + 1'b1 - diagonal_first_row(diagonal + 1'b1);
              end
            end
          end
        end
      endcase
    end
  end


endmodule

