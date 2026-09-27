`timescale 1ns / 1ps
module task_11 #(
    parameter int TASK_INPUT_WIDTH = 8,
    parameter int TASK_OUTPUT_WIDTH = 8
)(
    input wire i_clk, i_rst,
    input wire i_valid, i_first, i_last,
    input wire [TASK_INPUT_WIDTH-1:0] i_data,
    output logic o_valid, o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);
    localparam logic [7:0] MISSING = 8'hff;
    typedef enum logic [3:0] {
        IDLE, RX, SIZE, CLEAR, READ_ADDR, READ_WAIT, READ_DATA,
        TARGET, SOLVE, TX_ADDR, TX_WAIT, TX_DATA
    } state_t;
    state_t state;
    (* ram_style = "block" *) logic [7:0] mem [0:4095];
    logic [11:0] rd_addr;
    logic [7:0] rd_data;
    logic [12:0] total_count;
    logic [6:0] grid_size, size_candidate, clear_index, line_index;
    logic [11:0] scan_addr, tx_ptr;
    logic [5:0] scan_row, scan_col;
    logic [14:0] row_sum [0:63], col_sum [0:63];
    logic [6:0] row_missing [0:63], col_missing [0:63];
    // XOR of missing positions identifies the cell once just one remains.
    logic [5:0] row_xor [0:63], col_xor [0:63];
    logic [14:0] target_sum;
    logic target_valid, column_pass, progress_made;
    logic [5:0] repair_row, repair_col;
    logic [11:0] repair_addr;
    logic [14:0] repair_value;
    logic repair_valid;
    logic mem_we;
    logic [11:0] mem_waddr;
    logic [7:0] mem_wdata;

    always_comb begin
        repair_row = column_pass ? col_xor[line_index[5:0]] : line_index[5:0];
        repair_col = column_pass ? line_index[5:0] : row_xor[line_index[5:0]];
        repair_addr = repair_row * grid_size + repair_col;
        repair_value = target_sum - (column_pass ? col_sum[line_index[5:0]] : row_sum[line_index[5:0]]);
        repair_valid = state == SOLVE && target_valid &&
            (column_pass ? col_missing[line_index[5:0]] == 1 : row_missing[line_index[5:0]] == 1) &&
            target_sum >= (column_pass ? col_sum[line_index[5:0]] : row_sum[line_index[5:0]]) &&
            repair_value < 255;
    end

    // One synchronous read port and one synchronous write port.
    always_comb begin
        mem_we = 1'b0;
        mem_waddr = 0;
        mem_wdata = i_data[7:0];
        if (!i_rst) begin
            if (state == IDLE && i_valid && i_first) begin
                mem_we = 1'b1;
                mem_waddr = 0;
            end else if (state == RX && i_valid) begin
                mem_we = 1'b1;
                mem_waddr = total_count[11:0];
            end else if (repair_valid) begin
                mem_we = 1'b1;
                mem_waddr = repair_addr;
                mem_wdata = repair_value[7:0];
            end
        end
    end

    always_ff @(posedge i_clk) begin
        rd_data <= mem[rd_addr];
        if (mem_we) mem[mem_waddr] <= mem_wdata;
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
            total_count <= 0;
            grid_size <= 0;
            size_candidate <= 1;
            rd_addr <= 0;
            scan_addr <= 0;
            scan_row <= 0;
            scan_col <= 0;
            tx_ptr <= 0;
            clear_index <= 0;
            line_index <= 0;
            target_sum <= 0;
            target_valid <= 0;
            column_pass <= 0;
            progress_made <= 0;
            o_valid <= 0;
            o_last <= 0;
            o_data <= 0;
        end else begin
            o_valid <= 0;
            o_last <= 0;
            case (state)
                IDLE: if (i_valid && i_first) begin
                    total_count <= 1;
                    target_valid <= 0;
                    size_candidate <= 1;
                    tx_ptr <= 0;
                    state <= i_last ? SIZE : RX;
                end
                RX: if (i_valid) begin
                    total_count <= total_count + 1'b1;
                    if (i_last) state <= SIZE;
                end
                SIZE: begin
                    if (size_candidate * size_candidate == total_count) begin
                        grid_size <= size_candidate;
                        clear_index <= 0;
                        state <= CLEAR;
                    end else if (size_candidate == 64) begin
                        // Malformed non-square packet: return it unchanged.
                        tx_ptr <= 0;
                        state <= TX_ADDR;
                    end else size_candidate <= size_candidate + 1'b1;
                end
                CLEAR: begin
                    row_sum[clear_index[5:0]] <= 0;
                    col_sum[clear_index[5:0]] <= 0;
                    row_missing[clear_index[5:0]] <= 0;
                    col_missing[clear_index[5:0]] <= 0;
                    row_xor[clear_index[5:0]] <= 0;
                    col_xor[clear_index[5:0]] <= 0;
                    if (clear_index == 63) begin
                        scan_addr <= 0;
                        scan_row <= 0;
                        scan_col <= 0;
                        state <= READ_ADDR;
                    end else clear_index <= clear_index + 1'b1;
                end
                READ_ADDR: begin rd_addr <= scan_addr; state <= READ_WAIT; end
                READ_WAIT: state <= READ_DATA;
                READ_DATA: begin
                    if (rd_data == MISSING) begin
                        row_missing[scan_row] <= row_missing[scan_row] + 1'b1;
                        col_missing[scan_col] <= col_missing[scan_col] + 1'b1;
                        row_xor[scan_row] <= row_xor[scan_row] ^ scan_col;
                        col_xor[scan_col] <= col_xor[scan_col] ^ scan_row;
                    end else begin
                        row_sum[scan_row] <= row_sum[scan_row] + rd_data;
                        col_sum[scan_col] <= col_sum[scan_col] + rd_data;
                    end
                    if ({1'b0,scan_addr} + 13'd1 == total_count) begin
                        line_index <= 0;
                        state <= TARGET;
                    end else begin
                        scan_addr <= scan_addr + 1'b1;
                        if ({1'b0,scan_col} + 7'd1 == grid_size) begin
                            scan_col <= 0;
                            scan_row <= scan_row + 1'b1;
                        end else scan_col <= scan_col + 1'b1;
                        state <= READ_ADDR;
                    end
                end
                TARGET: begin
                    if (row_missing[line_index[5:0]] == 0 || col_missing[line_index[5:0]] == 0) begin
                        target_sum <= row_missing[line_index[5:0]] == 0 ?
                                      row_sum[line_index[5:0]] : col_sum[line_index[5:0]];
                        target_valid <= 1;
                        line_index <= 0;
                        column_pass <= 0;
                        progress_made <= 0;
                        state <= SOLVE;
                    end else if (line_index + 7'd1 == grid_size) begin
                        tx_ptr <= 0;
                        state <= TX_ADDR;
                    end else line_index <= line_index + 1'b1;
                end
                SOLVE: begin
                    if (repair_valid) begin
                        row_sum[repair_row] <= row_sum[repair_row] + repair_value;
                        col_sum[repair_col] <= col_sum[repair_col] + repair_value;
                        row_missing[repair_row] <= row_missing[repair_row] - 1'b1;
                        col_missing[repair_col] <= col_missing[repair_col] - 1'b1;
                        row_xor[repair_row] <= row_xor[repair_row] ^ repair_col;
                        col_xor[repair_col] <= col_xor[repair_col] ^ repair_row;
                        progress_made <= 1;
                    end
                    if (line_index + 7'd1 == grid_size) begin
                        line_index <= 0;
                        if (!column_pass) column_pass <= 1;
                        else if (progress_made || repair_valid) begin
                            column_pass <= 0;
                            progress_made <= 0;
                        end else begin
                            tx_ptr <= 0;
                            state <= TX_ADDR;
                        end
                    end else line_index <= line_index + 1'b1;
                end
                TX_ADDR: begin rd_addr <= tx_ptr; state <= TX_WAIT; end
                TX_WAIT: state <= TX_DATA;
                TX_DATA: begin
                    o_valid <= 1;
                    o_data <= rd_data;
                    o_last <= ({1'b0,tx_ptr} + 13'd1 == total_count);
                    if ({1'b0,tx_ptr} + 13'd1 == total_count) state <= IDLE;
                    else begin tx_ptr <= tx_ptr + 1'b1; state <= TX_ADDR; end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
