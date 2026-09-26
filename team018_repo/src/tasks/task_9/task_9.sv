`timescale 1ns / 1ps

module task_9 #(
    parameter int TASK_INPUT_WIDTH  = 32,
    parameter int TASK_OUTPUT_WIDTH = 32
)(
    input wire                          i_clk,
    input wire                          i_rst,

    input wire                          i_valid,
    input wire                          i_first,
    input wire                          i_last,
    input wire  [TASK_INPUT_WIDTH-1:0]  i_data,

    output logic                        o_valid,
    output logic                        o_first,
    output logic                        o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    localparam int MAX_INPUT_SAMPLES = 2048;

    // Inferencia de Block RAM (BRAM) para el menor consumo de registros (FFs)
    (* ram_style = "block" *) logic [31:0] sample_mem [0:MAX_INPUT_SAMPLES-1];

    typedef enum logic [2:0] {
        ST_WAIT_CONFIG,
        ST_RECEIVE,
        ST_CALC_INIT,
        ST_CALCULATE,
        ST_NORMALIZE,
        ST_OUTPUT_CONFIG,
        ST_OUTPUT_DATA
    } state_t;

    state_t state, next_state;

    // Configuración y registros de control
    logic [7:0]  num_pair, num_col_a, num_col_b;
    logic [5:0]  row_blocks, col_a_blocks, col_b_blocks;
    logic [11:0] samples_per_pair, input_samples, receive_count;
    logic [7:0]  pair_index;
    logic [5:0]  out_col_index, out_row_index, row_block_index;
    logic [11:0] pair_base;

    // Acumuladores reducidos a 40 bits para ahorrar LUTs (suficiente para rangos de acumulación)
    logic signed [47:0] sum_00, sum_01, sum_10, sum_11;
    logic [3:0]  result_exp;

    // Direcciones BRAM
    logic [10:0] addr_a, addr_b;
    logic [31:0] a_sample, b_sample;

    // Decodificación de muestras A y B
    logic signed [6:0] a_00, a_01, a_10, a_11;
    logic signed [6:0] b_00, b_01, b_10, b_11;
    logic [3:0] a_exp, b_exp;
    logic [4:0] product_exp;

    // BRAM Read
    always_ff @(posedge i_clk) begin
        if (i_valid && (state == ST_RECEIVE)) begin
            sample_mem[receive_count] <= i_data;
        end
        a_sample <= sample_mem[addr_a];
        b_sample <= sample_mem[addr_b];
    end

    // Direccionamiento BRAM
    always_comb begin
        addr_a = pair_base + out_col_index * row_blocks + row_block_index;
        addr_b = pair_base + col_a_blocks * row_blocks + out_row_index * row_blocks + row_block_index;
    end

    // Descomposición de las sub-cracovianas
    assign a_11 = a_sample[31:25];
    assign a_10 = a_sample[24:18];
    assign a_01 = a_sample[17:11];
    assign a_00 = a_sample[10:4];
    assign a_exp = a_sample[3:0];

    assign b_11 = b_sample[31:25];
    assign b_10 = b_sample[24:18];
    assign b_01 = b_sample[17:11];
    assign b_00 = b_sample[10:4];
    assign b_exp = b_sample[3:0];

    assign product_exp = {1'b0, a_exp} + {1'b0, b_exp};

    // Función de producto escalado compacta
    function automatic logic signed [47:0] scaled_prod(
        input logic signed [6:0] l,
        input logic signed [6:0] r,
        input logic [4:0] exp_in
    );
        logic signed [13:0] prod;
        begin
            prod = l * r;
            scaled_prod = {{34{prod[13]}}, prod} <<< exp_in;
        end
    endfunction

    // Módulos de cambio para la normalización (Prioridad ligera de desplazamientos)
    function automatic logic [5:0] get_shift(input logic signed [47:0] val);
        logic [47:0] mag;
        begin
            mag = (val < 0) ? -val : val;
            get_shift = 6'd0;
            for (int i = 47; i >= 6; i--) begin
                if (mag[i]) return i - 5;
            end
        end
    endfunction

    logic [5:0] s0, s1, s2, s3, max_shift;
    always_comb begin
        s0 = get_shift(sum_00);
        s1 = get_shift(sum_01);
        s2 = get_shift(sum_10);
        s3 = get_shift(sum_11);
        max_shift = s0;
        if (s1 > max_shift) max_shift = s1;
        if (s2 > max_shift) max_shift = s2;
        if (s3 > max_shift) max_shift = s3;
    end

    // FSM Principal
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state <= ST_WAIT_CONFIG;
            receive_count <= '0;
            pair_index <= '0;
            out_col_index <= '0;
            out_row_index <= '0;
            row_block_index <= '0;
            pair_base <= '0;
            sum_00 <= '0;
            sum_01 <= '0;
            sum_10 <= '0;
            sum_11 <= '0;
            result_exp <= '0;
        end else begin
            state <= next_state;

            case (state)
                ST_WAIT_CONFIG: begin
                    if (i_valid && i_first) begin
                        num_pair        <= i_data[31:24];
                        num_col_a       <= i_data[15:8];
                        num_col_b       <= i_data[7:0];
                        row_blocks      <= i_data[23:17];
                        col_a_blocks    <= i_data[15:9];
                        col_b_blocks    <= i_data[7:1];
                        samples_per_pair <= i_data[23:17] * (i_data[15:9] + i_data[7:1]);
                        input_samples   <= i_data[31:24] * (i_data[23:17] * (i_data[15:9] + i_data[7:1]));
                        receive_count   <= '0;
                    end
                end

                ST_RECEIVE: begin
                    if (i_valid) begin
                        receive_count <= receive_count + 1'b1;
                    end
                end

                ST_CALC_INIT: begin
                    pair_index      <= '0;
                    out_col_index   <= '0;
                    out_row_index   <= '0;
                    row_block_index <= '0;
                    pair_base       <= '0;
                    sum_00          <= '0;
                    sum_01          <= '0;
                    sum_10          <= '0;
                    sum_11          <= '0;
                end

                ST_CALCULATE: begin
                    sum_00 <= sum_00 + scaled_prod(a_00, b_00, product_exp) + scaled_prod(a_10, b_10, product_exp);
                    sum_01 <= sum_01 + scaled_prod(a_01, b_00, product_exp) + scaled_prod(a_11, b_10, product_exp);
                    sum_10 <= sum_10 + scaled_prod(a_00, b_01, product_exp) + scaled_prod(a_10, b_11, product_exp);
                    sum_11 <= sum_11 + scaled_prod(a_01, b_01, product_exp) + scaled_prod(a_11, b_11, product_exp);

                    if (row_block_index == row_blocks - 1'b1)
                        row_block_index <= '0;
                    else
                        row_block_index <= row_block_index + 1'b1;
                end

                ST_NORMALIZE: begin
                    result_exp <= max_shift[3:0];
                    sum_00 <= sum_00 >>> max_shift;
                    sum_01 <= sum_01 >>> max_shift;
                    sum_10 <= sum_10 >>> max_shift;
                    sum_11 <= sum_11 >>> max_shift;
                end

                ST_OUTPUT_DATA: begin
                    sum_00 <= '0;
                    sum_01 <= '0;
                    sum_10 <= '0;
                    sum_11 <= '0;
                    if (out_row_index == col_b_blocks - 1'b1) begin
                        out_row_index <= '0;
                        if (out_col_index == col_a_blocks - 1'b1) begin
                            out_col_index <= '0;
                            if (pair_index != num_pair - 1'b1) begin
                                pair_index <= pair_index + 1'b1;
                                pair_base  <= pair_base + samples_per_pair;
                            end
                        end else begin
                            out_col_index <= out_col_index + 1'b1;
                        end
                    end else begin
                        out_row_index <= out_row_index + 1'b1;
                    end
                end
            endcase
        end
    end

    // Transición de estados y señales de salida
    always_comb begin
        next_state = state;
        o_valid = 1'b0;
        o_first = 1'b0;
        o_last  = 1'b0;
        o_data  = '0;

        case (state)
            ST_WAIT_CONFIG: begin
                if (i_valid && i_first)
                    next_state = i_last ? ST_CALC_INIT : ST_RECEIVE;
            end

            ST_RECEIVE: begin
                if (i_valid && (i_last || (receive_count == input_samples - 1'b1)))
                    next_state = ST_CALC_INIT;
            end

            ST_CALC_INIT: next_state = ST_CALCULATE;

            ST_CALCULATE: begin
                if (row_block_index == row_blocks - 1'b1)
                    next_state = ST_NORMALIZE;
            end

            ST_NORMALIZE: begin
                if ((pair_index == '0) && (out_col_index == '0) && (out_row_index == '0))
                    next_state = ST_OUTPUT_CONFIG;
                else
                    next_state = ST_OUTPUT_DATA;
            end

            ST_OUTPUT_CONFIG: begin
                o_valid = 1'b1;
                o_first = 1'b1;
                o_data  = {num_pair, num_col_b, 8'd0, num_col_a}; // Configuración formateada correctamente[cite: 6]
                next_state = ST_OUTPUT_DATA;
            end

            ST_OUTPUT_DATA: begin
                o_valid = 1'b1;
                o_data  = {sum_11[6:0], sum_10[6:0], sum_01[6:0], sum_00[6:0], result_exp};
                o_last  = (pair_index == num_pair - 1'b1) &&
                          (out_col_index == col_a_blocks - 1'b1) &&
                          (out_row_index == col_b_blocks - 1'b1);
                
                next_state = o_last ? ST_WAIT_CONFIG : ST_CALCULATE;
            end

            default: next_state = ST_WAIT_CONFIG;
        endcase
    end

endmodule