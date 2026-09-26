`timescale 1ns / 1ps

// Task 4: positivos (incluido 0) ascendentes; negativos descendentes.
// Mientras existan ambos, positivo en índice par y negativo en índice impar.
module task_4
#(
    parameter int TASK_INPUT_WIDTH  = 16,
    parameter int TASK_OUTPUT_WIDTH = 16,
    parameter int INPUT_STREAMS     = 1,
    parameter int OUTPUT_STREAMS    = 1
)(
    input  logic                               i_clk,
    input  logic                               i_rst,
    input  logic                               i_valid,
    input  logic                               i_first,
    input  logic                               i_last,
    input  logic signed [TASK_INPUT_WIDTH-1:0] i_data,
    output logic                               o_valid,
    output logic                               o_last,
    output logic signed [TASK_OUTPUT_WIDTH-1:0] o_data
);

    // 4 KiB / 2 bytes por muestra de 16 bits.
    localparam int MAX_SAMPLES = 2048;

    typedef enum logic [3:0] {
        ST_0,          // Espera i_first.
        ST_RECV,       // Recibe y separa positivos/negativos.
        ST_POS_INIT,   // Inicializa bubble sort de positivos.
        ST_POS_SORT,   // Positivos en orden ascendente.
        ST_NEG_INIT,   // Inicializa bubble sort de negativos.
        ST_NEG_SORT,   // Negativos en orden descendente.
        ST_OUT_INIT,   // Reinicia índices de salida.
        ST_OUTPUT,     // Emite una muestra por ciclo.
        ST_DONE        // Cierre del paquete.
    } state_t;

    state_t state, next_state;

    logic signed [15:0] pos_mem [0:MAX_SAMPLES-1];
    logic signed [15:0] neg_mem [0:MAX_SAMPLES-1];

    // Los counts deben representar 2048; los índices sólo llegan a 2047.
    logic [11:0] pos_count, neg_count;
    logic [10:0] sort_i, sort_j;
    logic [11:0] pos_out_idx, neg_out_idx, out_count;
    logic        send_positive;

    // Registro de estado: únicamente guarda el siguiente estado calculado.
    always_ff @(posedge i_clk) begin
        if (i_rst)
            state <= ST_0;
        else
            state <= next_state;
    end

    // RECEPCIÓN y SWAPS de ordenamiento: siempre con reloj.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            pos_count <= '0;
            neg_count <= '0;
        end else begin
            case (state)
                ST_0: begin
                    // i_first marca el primer dato; también debe guardarse.
                    if (i_valid && i_first) begin
                        if (i_data >= 0) begin
                            pos_mem[0] <= i_data;
                            pos_count  <= 12'd1;
                            neg_count  <= '0;
                        end else begin
                            neg_mem[0] <= i_data;
                            neg_count  <= 12'd1;
                            pos_count  <= '0;
                        end
                    end
                end

                ST_RECV: begin
                    if (i_valid) begin
                        // El cero va en positivos, como exige el enunciado.
                        if (i_data >= 0) begin
                            pos_mem[pos_count] <= i_data;
                            pos_count <= pos_count + 1'b1;
                        end else begin
                            neg_mem[neg_count] <= i_data;
                            neg_count <= neg_count + 1'b1;
                        end
                    end
                end

                ST_POS_SORT: begin
                    // Bubble sort ascendente: izquierda mayor que derecha.
                    if (sort_i < pos_count - 1'b1 &&
                        pos_mem[sort_j] > pos_mem[sort_j + 1'b1]) begin
                        pos_mem[sort_j]        <= pos_mem[sort_j + 1'b1];
                        pos_mem[sort_j + 1'b1] <= pos_mem[sort_j];
                    end
                end

                ST_NEG_SORT: begin
                    // Bubble sort descendente: -1 debe quedar antes que -2.
                    if (sort_i < neg_count - 1'b1 &&
                        neg_mem[sort_j] < neg_mem[sort_j + 1'b1]) begin
                        neg_mem[sort_j]        <= neg_mem[sort_j + 1'b1];
                        neg_mem[sort_j + 1'b1] <= neg_mem[sort_j];
                    end
                end

                default: begin end
            endcase
        end
    end

    // Dos contadores implementan los bucles del bubble sort, un compare por ciclo.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            sort_i <= '0;
            sort_j <= '0;
        end else if (state == ST_POS_INIT || state == ST_NEG_INIT) begin
            sort_i <= '0;
            sort_j <= '0;
        end else if (state == ST_POS_SORT && sort_i < pos_count - 1'b1) begin
            if (sort_j == pos_count - sort_i - 12'd2) begin
                sort_j <= '0;
                sort_i <= sort_i + 1'b1;
            end else begin
                sort_j <= sort_j + 1'b1;
            end
        end else if (state == ST_NEG_SORT && sort_i < neg_count - 1'b1) begin
            if (sort_j == neg_count - sort_i - 12'd2) begin
                sort_j <= '0;
                sort_i <= sort_i + 1'b1;
            end else begin
                sort_j <= sort_j + 1'b1;
            end
        end
    end

    // Índices de salida: avanzan sólo después de entregar un dato válido.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            pos_out_idx <= '0;
            neg_out_idx <= '0;
            out_count   <= '0;
        end else if (state == ST_OUT_INIT) begin
            pos_out_idx <= '0;
            neg_out_idx <= '0;
            out_count   <= '0;
        end else if (state == ST_OUTPUT) begin
            if (send_positive)
                pos_out_idx <= pos_out_idx + 1'b1;
            else
                neg_out_idx <= neg_out_idx + 1'b1;
            out_count <= out_count + 1'b1;
        end
    end

    // LÓGICA COMBINACIONAL: sólo next_state y la interfaz de salida.
    always_comb begin
        next_state    = state;
        o_valid       = 1'b0;
        o_last        = 1'b0;
        o_data        = '0;
        send_positive = 1'b0;

        case (state)
            ST_0: begin
                if (i_valid && i_first) begin
                    // También funciona con un paquete de una única muestra.
                    if (i_last)
                        next_state = ST_POS_INIT;
                    else
                        next_state = ST_RECV;
                end
            end

            ST_RECV: begin
                if (i_valid && i_last)
                    next_state = ST_POS_INIT;
            end

            ST_POS_INIT: begin
                if (pos_count < 12'd2)
                    next_state = ST_NEG_INIT;
                else
                    next_state = ST_POS_SORT;
            end

            ST_POS_SORT: begin
                if (sort_i >= pos_count - 1'b1)
                    next_state = ST_NEG_INIT;
            end

            ST_NEG_INIT: begin
                if (neg_count < 12'd2)
                    next_state = ST_OUT_INIT;
                else
                    next_state = ST_NEG_SORT;
            end

            ST_NEG_SORT: begin
                if (sort_i >= neg_count - 1'b1)
                    next_state = ST_OUT_INIT;
            end

            ST_OUT_INIT: next_state = ST_OUTPUT;

            ST_OUTPUT: begin
                // Si hay ambas listas: salida par = positivo; impar = negativo.
                if (pos_out_idx < pos_count && neg_out_idx < neg_count)
                    send_positive = ~out_count[0];
                else if (pos_out_idx < pos_count)
                    send_positive = 1'b1;
                else
                    send_positive = 1'b0;

                o_valid = 1'b1;
                o_data  = send_positive ? pos_mem[pos_out_idx] : neg_mem[neg_out_idx];
                o_last  = (out_count == pos_count + neg_count - 1'b1);

                if (o_last)
                    next_state = ST_DONE;
            end

            ST_DONE: next_state = ST_0;
            default: next_state = ST_0;
        endcase
    end

endmodule
