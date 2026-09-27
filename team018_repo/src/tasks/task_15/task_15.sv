`timescale 1ns / 1ps

module task_15 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8
)(
    input  wire                          i_clk,
    input  wire                          i_rst,

    input  wire                          i_valid,
    input  wire                          i_first,
    input  wire                          i_last,
    input  wire [TASK_INPUT_WIDTH-1:0]  i_data,

    output logic                         o_valid,
    output logic                         o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    // Estados de la FSM
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RX_N,
        ST_RX_H,
        ST_BUILD_G,
        ST_ENCODE,
        ST_WRITE_MEM,
        ST_TX_STREAM
    } state_t;

    state_t state;

    // memorias compatibles con Block RAM / Distributed RAM
    (* ram_style = "distributed" *) logic [255:0] h_matrix [0:63]; 
    (* ram_style = "distributed" *) logic [255:0] g_matrix [0:63]; 
    (* ram_style = "block" *)       logic [7:0]   out_mem  [0:4095]; 

    // Registros de dimensión y control
    logic [12:0] rx_byte_cnt;
    logic [6:0] rx_row;
    logic [7:0] rx_col;
    logic [5:0]  h_rows;        // m = filas de H
    logic [7:0]  n_bits;        // n = columnas de H / G
    logic [5:0]  k_bits;        // k = filas de G (n - m)
    logic [3:0]  n_bytes;       // ceil(n / 8)

    // Contadores de procesamiento
    logic [11:0] u_counter;     // Mensaje u (0 a 2^k - 1)
    logic [12:0] total_words;   // 2^k palabras
    logic [7:0]  byte_idx;      // One output byte per codeword bit.
    logic [12:0] wr_ptr;        // Puntero de escritura en out_mem
    logic [12:0] tx_ptr;        // Puntero de lectura/transmisión de bytes
    logic [12:0] total_tx_bytes;

    // Registro para almacenar la palabra codificada actual c = u * G
    logic [255:0] current_codeword;

    // -------------------------------------------------------------------------
    // FSM Secuencial
    // -------------------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state            <= ST_IDLE;
            o_valid          <= 1'b0;
            o_last           <= 1'b0;
            o_data           <= 8'h00;
            rx_byte_cnt      <= '0;
            rx_row           <= '0;
            rx_col           <= '0;
            h_rows           <= '0;
            n_bits           <= '0;
            k_bits           <= '0;
            n_bytes          <= '0;
            u_counter        <= '0;
            byte_idx         <= '0;
            wr_ptr           <= '0;
            tx_ptr           <= '0;
            total_tx_bytes   <= '0;
            total_words      <= '0;
            current_codeword <= '0;
        end else begin
            case (state)

                // -------------------------------------------------------------
                // ST_IDLE: Espera del primer byte con i_first = 1 (Header: h_rows)
                // -------------------------------------------------------------
                ST_IDLE: begin
                    o_valid <= 1'b0;
                    o_last  <= 1'b0;
                    if (i_valid && i_first) begin
                        h_rows      <= i_data[5:0]; // Extrae correctamente las filas de H
                        rx_byte_cnt <= '0;
                        rx_row      <= '0;
                        rx_col      <= '0;
                        state       <= ST_RX_N;
                    end
                end

                ST_RX_N: begin
                    if (i_valid) begin
                        n_bits  <= i_data;
                        k_bits  <= i_data - h_rows;
                        n_bytes <= ({1'b0, i_data} + 9'd7) >> 3;
                        state   <= ST_RX_H;
                    end
                end

                // -------------------------------------------------------------
                // ST_RX_H: Recepción streaming de la matriz H
                // -------------------------------------------------------------
                ST_RX_H: begin
                    if (i_valid) begin
                        if (rx_row < h_rows && rx_col < n_bits) begin
                            h_matrix[rx_row][rx_col] <= i_data[0];
                            if (rx_col == n_bits - 1'b1) begin
                                rx_col <= '0;
                                rx_row <= rx_row + 1'b1;
                            end else begin
                                rx_col <= rx_col + 1'b1;
                            end
                        end
                        rx_byte_cnt <= rx_byte_cnt + 1'b1;

                        if (i_last) begin
                            state <= ST_BUILD_G;
                        end
                    end
                end

                // -------------------------------------------------------------
                // ST_BUILD_G: Generación de la Matriz Generadora G = [I_k | P]
                // -------------------------------------------------------------
                ST_BUILD_G: begin
                    // Prevención de overflow en total_words (máximo 4096 palabras)
                    automatic logic [5:0] safe_k = (k_bits > 12) ? 6'd12 : k_bits;
                    
                    total_words    <= (1'b1 << safe_k);
                    total_tx_bytes <= (13'd1 << safe_k) * n_bits;

                    // Construcción explícita de G_matrix bit a bit en ciclos/paralelo interno
                    for (int r = 0; r < 64; r++) begin
                        if (r < k_bits) begin
                            g_matrix[r] <= '0;
                            // 1. Matriz Identidad I_k
                            g_matrix[r][r] <= 1'b1; 
                            
                            // 2. Matriz P obtenida de P^T en H (H = [P^T | I_m])
                            for (int c = 0; c < 64; c++) begin
                                if (c < h_rows) begin
                                    g_matrix[r][k_bits + c] <= h_matrix[c][r];
                                end
                            end
                        end
                    end

                    u_counter <= '0;
                    wr_ptr    <= '0;
                    state     <= ST_ENCODE;
                end

                // -------------------------------------------------------------
                // ST_ENCODE: Cálculo vectorial c = u * G (XOR)
                // -------------------------------------------------------------
                ST_ENCODE: begin
                    automatic logic [255:0] codeword = '0;

                    // Enumerate messages most-significant bit first, matching
                    // the column order of the systematic generator matrix.
                    for (int i = 0; i < 12; i++) begin
                        if (i < k_bits) begin
                            if (u_counter[k_bits - 1 - i])
                                codeword = codeword ^ g_matrix[i];
                        end
                    end

                    current_codeword <= codeword;
                    byte_idx         <= '0;
                    state            <= ST_WRITE_MEM;
                end

                // -------------------------------------------------------------
                // ST_WRITE_MEM: Escritura secuencial byte a byte en out_mem (BRAM)
                // -------------------------------------------------------------
                ST_WRITE_MEM: begin
                    if (wr_ptr < 4096) begin
                        out_mem[wr_ptr] <= {7'b0, current_codeword[byte_idx]};
                    end

                    wr_ptr <= wr_ptr + 1'b1;

                    if (byte_idx == (n_bits - 1'b1)) begin
                        if (u_counter == (total_words - 1'b1)) begin
                            tx_ptr <= '0;
                            state  <= ST_TX_STREAM;
                        end else begin
                            u_counter <= u_counter + 1'b1;
                            state     <= ST_ENCODE;
                        end
                    end else begin
                        byte_idx <= byte_idx + 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // ST_TX_STREAM: Transmisión AXI-Stream / Valido-Listo de salida
                // -------------------------------------------------------------
                ST_TX_STREAM: begin
                    o_valid <= 1'b1;
                    o_data  <= out_mem[tx_ptr];

                    if (tx_ptr == (total_tx_bytes - 1'b1)) begin
                        o_last <= 1'b1;
                        state  <= ST_IDLE;
                    end else begin
                        o_last <= 1'b0;
                        tx_ptr <= tx_ptr + 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
