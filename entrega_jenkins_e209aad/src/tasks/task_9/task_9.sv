`timescale 1ns / 1ps

module task_9 #(
    parameter int TASK_INPUT_WIDTH = 32,
    parameter int TASK_OUTPUT_WIDTH = 32
)(
    input wire i_clk, i_rst, i_valid, i_first, i_last,
    input wire [TASK_INPUT_WIDTH-1:0] i_data,
    output logic o_valid, o_first, o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);
    // Two interleaved banks with synchronous reads. No RAM reset.
    (* ram_style = "block" *) logic [31:0] sample_even [0:1023];
    (* ram_style = "block" *) logic [31:0] sample_odd [0:1023];
    typedef enum logic [2:0] {IDLE, RECEIVE, HEADER, ISSUE, DRAIN} state_t;
    state_t state;
    logic [7:0] num_pairs, cols_a, cols_b, pair_index;
    logic [5:0] row_blocks, ca_blocks, cb_blocks, ca, cb, rb;
    logic [11:0] receive_count, input_samples, samples_per_pair, pair_base;
    logic [10:0] addr_a, addr_b, addr_a_next, addr_b_next;
    logic [31:0] a_even, a_odd, b_even, b_odd;
    logic a_parity, b_parity;
    wire [31:0] a0 = a_parity ? a_odd : a_even;
    wire [31:0] a1 = a_parity ? a_even : a_odd;
    wire [31:0] b0 = b_parity ? b_odd : b_even;
    wire [31:0] b1 = b_parity ? b_even : b_odd;
    logic rd_valid, rd_first, rd_last, rd_final, rd_extra;
    logic mul_valid, mul_first, mul_last, mul_final;
    logic add_valid, add_first, add_last, add_final;
    logic result_valid, result_final;
    // 64 rows * (-64 * -64) * 2^30 can equal +2^48: signed 50 bits.
    logic signed [49:0] products [0:3][0:3];
    logic signed [49:0] contribution [0:3], accumulator [0:3], result [0:3];
    logic [5:0] norm_shift;

    function automatic logic signed [49:0] scaled_product(
        input logic signed [6:0] a, b, input logic [4:0] exponent);
        logic signed [13:0] p;
        logic signed [49:0] wide;
        begin
            p = a * b;
            wide = {{36{p[13]}}, p};
            return wide <<< exponent;
        end
    endfunction

    // Preserve tested absolute-magnitude normalization. Values requiring
    // exponent >15 remain outside the documented representable output range.
    function automatic logic [5:0] required_shift(input logic signed [49:0] v);
        logic [49:0] magnitude;
        begin
            magnitude = v < 0 ? -v : v;
            for (int bit_index=49; bit_index>=6; bit_index--)
                if (magnitude[bit_index]) return bit_index - 5;
            return 0;
        end
    endfunction

    always_comb begin
        addr_a = pair_base + ca * row_blocks + rb;
        addr_b = pair_base + ca_blocks * row_blocks + cb * row_blocks + rb;
        addr_a_next = addr_a + 1'b1;
        addr_b_next = addr_b + 1'b1;
        norm_shift = required_shift(result[0]);
        for (int k=1; k<4; k++)
            if (required_shift(result[k]) > norm_shift)
                norm_shift = required_shift(result[k]);
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst && i_valid && state == RECEIVE) begin
            if (receive_count[0]) sample_odd[receive_count[10:1]] <= i_data;
            else sample_even[receive_count[10:1]] <= i_data;
        end
        a_even <= sample_even[addr_a_next[10:1]];
        a_odd <= sample_odd[addr_a[10:1]];
        b_even <= sample_even[addr_b_next[10:1]];
        b_odd <= sample_odd[addr_b[10:1]];
        a_parity <= addr_a[0];
        b_parity <= addr_b[0];
    end

    // Continuous requests. Tags delimit dot products instead of FSM bubbles.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
            receive_count <= 0; pair_index <= 0; pair_base <= 0;
            ca <= 0; cb <= 0; rb <= 0;
            num_pairs <= 0; cols_a <= 0; cols_b <= 0;
            row_blocks <= 0; ca_blocks <= 0; cb_blocks <= 0;
            input_samples <= 0; samples_per_pair <= 0;
        end else begin
            case (state)
                IDLE: if (i_valid && i_first) begin
                    num_pairs <= i_data[31:24];
                    cols_a <= i_data[15:8]; cols_b <= i_data[7:0];
                    row_blocks <= i_data[23:17];
                    ca_blocks <= i_data[15:9]; cb_blocks <= i_data[7:1];
                    samples_per_pair <= i_data[23:17] * (i_data[15:9]+i_data[7:1]);
                    input_samples <= i_data[31:24] * (i_data[23:17] * (i_data[15:9]+i_data[7:1]));
                    receive_count <= 0;
                    state <= RECEIVE;
                end
                RECEIVE: if (i_valid) begin
                    receive_count <= receive_count + 1'b1;
                    if (i_last || receive_count == input_samples-1'b1) begin
                        ca <= 0; cb <= 0; rb <= 0; pair_index <= 0; pair_base <= 0;
                        state <= HEADER;
                    end
                end
                HEADER: state <= ISSUE;
                ISSUE: begin
                    if (rb + 2 >= row_blocks) begin
                        rb <= 0;
                        if (cb == cb_blocks-1'b1) begin
                            cb <= 0;
                            if (ca == ca_blocks-1'b1) begin
                                ca <= 0;
                                if (pair_index == num_pairs-1'b1) state <= DRAIN;
                                else begin
                                    pair_index <= pair_index+1'b1;
                                    pair_base <= pair_base+samples_per_pair;
                                end
                            end else ca <= ca+1'b1;
                        end else cb <= cb+1'b1;
                    end else rb <= rb+2;
                end
                DRAIN: if (result_valid && result_final) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            rd_valid <= 0; mul_valid <= 0; add_valid <= 0; result_valid <= 0;
            rd_first <= 0; rd_last <= 0; rd_final <= 0; rd_extra <= 0;
            mul_first <= 0; mul_last <= 0; mul_final <= 0;
            add_first <= 0; add_last <= 0; add_final <= 0; result_final <= 0;
            o_valid <= 0; o_first <= 0; o_last <= 0; o_data <= 0;
        end else begin
            rd_valid <= state == ISSUE;
            rd_first <= rb == 0;
            rd_last <= rb+2 >= row_blocks;
            rd_extra <= rb+1 < row_blocks;
            rd_final <= rb+2 >= row_blocks && cb == cb_blocks-1'b1 &&
                        ca == ca_blocks-1'b1 && pair_index == num_pairs-1'b1;
            mul_valid <= rd_valid;
            mul_first <= rd_first; mul_last <= rd_last; mul_final <= rd_final;
            add_valid <= mul_valid;
            add_first <= mul_first; add_last <= mul_last; add_final <= mul_final;
            result_valid <= add_valid && add_last;
            result_final <= add_final;
            for (int k=0; k<4; k++) begin
                // C[rowB][colA] = B^T * A, with 2 input row-blocks per request.
                products[k][0] <= scaled_product(a0[4+7*(k%2)+:7], b0[4+7*(k/2)+:7], {1'b0,a0[3:0]}+{1'b0,b0[3:0]});
                products[k][1] <= scaled_product(a0[18+7*(k%2)+:7], b0[18+7*(k/2)+:7], {1'b0,a0[3:0]}+{1'b0,b0[3:0]});
                products[k][2] <= rd_extra ? scaled_product(a1[4+7*(k%2)+:7], b1[4+7*(k/2)+:7], {1'b0,a1[3:0]}+{1'b0,b1[3:0]}) : 50'sd0;
                products[k][3] <= rd_extra ? scaled_product(a1[18+7*(k%2)+:7], b1[18+7*(k/2)+:7], {1'b0,a1[3:0]}+{1'b0,b1[3:0]}) : 50'sd0;
                contribution[k] <= (products[k][0]+products[k][1]) + (products[k][2]+products[k][3]);
                if (add_valid) begin
                    accumulator[k] <= (add_first ? 50'sd0 : accumulator[k]) + contribution[k];
                    if (add_last)
                        result[k] <= (add_first ? 50'sd0 : accumulator[k]) + contribution[k];
                end
            end
            o_valid <= state == HEADER || result_valid;
            o_first <= state == HEADER;
            o_last <= result_valid && result_final;
            if (state == HEADER) o_data <= {num_pairs,cols_b,8'd0,cols_a};
            else if (result_valid) begin
                o_data[3:0] <= norm_shift[3:0];
                for (int k=0; k<4; k++) o_data[4+7*k+:7] <= result[k] >>> norm_shift;
            end
        end
    end
endmodule
