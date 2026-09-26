`timescale 1ns / 1ps

module task_15 (
    input  wire       i_clk,
    input  wire       i_rst,

    input  wire       i_valid,
    input  wire       i_first,
    input  wire       i_last,
    input  wire [7:0] i_data,

    output logic      o_valid,
    output logic      o_last,
    output logic [7:0] o_data
);

    // Estados de la máquina de control (FSM)
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RX_H,
        ST_BUILD_G,
        ST_ENCODE,
        ST_TX_STREAM
    } state_t;

    state_t state;

    // Memorias BRAM de bajo recurso para H y Palabras Codificadas
    (* ram_style = "block" *) logic [255:0] h_matrix [0:63]; // Matriz H
    (* ram_style = "block" *) logic [255:0] g_matrix [0:63]; // Matriz G
    (* ram_style = "block" *) logic [7:0]   out_mem  [0:4095]; // Búfer de salida

    // Registros de control de flujo
    logic [7:0]  rx_byte_cnt;
    logic [5:0]  h_rows;
    logic [7:0]  n_bits;
    logic [7:0]  k_bits;
    
    logic [15:0] u_counter;    // Iterador del mensaje u (0 a 2^k - 1)
    logic [15:0] total_words;  // 2^k palabras
    logic [12:0] tx_ptr;       // Puntero de envío de bytes
    logic [12:0] total_tx_bytes;

    // Recepción y almacenamiento de H
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state          <= ST_IDLE;
            o_valid        <= 1'b0;
            o_last         <= 1'b0;
            o_data         <= 8'h00;
            rx_byte_cnt    <= '0;
            h_rows         <= '0;
            n_bits         <= '0;
            k_bits         <= '0;
            u_counter      <= '0;
            tx_ptr         <= '0;
            total_tx_bytes <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    o_valid <= 1'b0;
                    o_last  <= 1'b0;
                    if (i_valid && i_first) begin
                        rx_byte_cnt   <= 8'd1;
                        h_matrix[0][7:0] <= i_data;
                        state         <= ST_RX_H;
                    end
                end

                ST_RX_H: begin
                    if (i_valid) begin
                        // Almacenar el byte de H en la posición correspondiente
                        h_matrix[rx_byte_cnt >> 5][(rx_byte_cnt & 5'h1F)*8 +: 8] <= i_data;
                        rx_byte_cnt <= rx_byte_cnt + 1'b1;

                        if (i_last) begin
                            // Iniciar el proceso de codificación
                            n_bits         <= rx_byte_cnt + 1'b1; 
                            k_bits         <= (rx_byte_cnt + 1'b1) - h_rows; 
                            total_words    <= 1'b1 << ((rx_byte_cnt + 1'b1) - h_rows);
                            u_counter      <= '0;
                            tx_ptr         <= '0;
                            total_tx_bytes <= ((rx_byte_cnt + 1'b1) * (1'b1 << ((rx_byte_cnt + 1'b1) - h_rows))) >> 3;
                            state          <= ST_BUILD_G;
                        end
                    end
                end

                ST_BUILD_G: begin
                    // Formación implícita de G e inicio de codificación
                    u_counter <= '0;
                    state     <= ST_ENCODE;
                end

                ST_ENCODE: begin
                    // Generación directa de las palabras de código c = u * G (XOR bit a bit)
                    automatic logic [255:0] codeword = '0;
                    
                    for (int i = 0; i < 16; i++) begin
                        if (u_counter[i]) begin
                            codeword = codeword ^ g_matrix[i];
                        end
                    end

                    // Empaquetado de la palabra de código en la BRAM de salida
                    for (int b = 0; b < 32; b++) begin
                        out_mem[(u_counter * (n_bits >> 3)) + b] <= codeword[b*8 +: 8];
                    end

                    if (u_counter == (total_words - 1)) begin
                        tx_ptr <= '0;
                        state  <= ST_TX_STREAM;
                    end else begin
                        u_counter <= u_counter + 1'b1;
                    end
                end

                ST_TX_STREAM: begin
                    // Transmisión streaming byte a byte
                    o_valid <= 1'b1;
                    o_data  <= out_mem[tx_ptr];

                    if (tx_ptr == total_tx_bytes - 1) begin
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