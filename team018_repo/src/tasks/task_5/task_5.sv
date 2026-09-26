`timescale 1ns / 1ps

module task_5 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8,
    parameter int NUM_OF_ROTORS     = 2,
    parameter int MAX_MSG_LENGTH    = 1024,
    parameter int ALPHABET_SIZE     = 128
) (
    input wire                         i_clk,
    input wire                         i_rst,

    input wire                         i_valid,
    input wire                         i_first,
    input wire                         i_last,
    input wire [TASK_INPUT_WIDTH-1:0] i_data,

    output logic                         o_valid,
    output logic                         o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    // Prefijo conocido de referencia para la verificación
    localparam int PREFIX_LEN = 45;
    localparam byte PREFIX[0:PREFIX_LEN-1] = '{
        "H", "e", "l", "l", "o", ",", " ", "F", "P", "G", "A", " ", 
        "H", "a", "c", "k", "a", "t", "h", "o", "n", "!", " ", "Y", 
        "o", "u", "r", " ", "s", "e", "c", "r", "e", "t", " ", "m", 
        "e", "s", "s", "a", "g", "e", " ", "i", "s", ":", " "
    };

    // Almacenamiento del mensaje de entrada
    logic [7:0] msg_mem [0:MAX_MSG_LENGTH-1];
    logic [10:0] msg_length;
    logic [10:0] rx_cnt;

    // Registros para el espacio de búsqueda brute-force
    logic [6:0] key_r0;
    logic [6:0] key_r1;
    logic [6:0] key_ref;

    // Rotores para simular el avance durante la verificación/desencriptación
    logic [6:0] rot0, rot1;
    logic [15:0] step_cnt;

    // Estados de la máquina de estados
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_STORE,
        ST_CHECK_KEY,
        ST_ADVANCE_KEY,
        ST_STREAM_OUT
    } state_t;

    state_t state;

    // Posición y control de lectura de salida
    logic [10:0] tx_cnt;

    // --- Función de desencriptación de un solo carácter ---
    function automatic logic [7:0] decode_byte(
        input logic [7:0] in_char,
        input logic [6:0] r0,
        input logic [6:0] r1,
        input logic [6:0] ref_pos
    );
        logic [6:0] c;
        c = in_char[6:0];
        
        // Forward pass
        c = (c - 7'd1) ^ r0;
        c = (c - 7'd1) ^ r1;
        
        // Reflector
        c = c ^ ref_pos;
        
        // Backward pass
        c = (c - 7'd1) ^ r1;
        c = (c - 7'd1) ^ r0;

        return {1'b0, c};
    endfunction

    // --- Lógica principal y FSM ---
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state      <= ST_IDLE;
            rx_cnt     <= '0;
            tx_cnt     <= '0;
            msg_length <= '0;
            key_r0     <= '0;
            key_r1     <= '0;
            key_ref    <= '0;
            o_valid    <= 1'b0;
            o_last     <= 1'b0;
            o_data     <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    o_valid <= 1'b0;
                    o_last  <= 1 me;
                    if (i_valid && i_first) begin
                        msg_mem[0] <= i_data;
                        rx_cnt     <= 1;
                        state      <= ST_STORE;
                    end
                end

                ST_STORE: begin
                    if (i_valid) begin
                        msg_mem[rx_cnt] <= i_data;
                        rx_cnt          <= rx_cnt + 1'b1;
                        if (i_last) begin
                            msg_length <= rx_cnt + 1'b1;
                            // Iniciar búsqueda de clave
                            key_r0   <= '0;
                            key_r1   <= '0;
                            key_ref  <= '0;
                            state    <= ST_CHECK_KEY;
                        end
                    end
                end

                ST_CHECK_KEY: begin
                    // Probar la clave actual comparando el primer carácter
                    if (decode_byte(msg_mem[0], key_r0, key_r1, key_ref) == PREFIX[0]) begin
                        // Si coincide el primer carácter, verificamos los siguientes
                        logic match;
                        logic [6:0] cur_r0, cur_r1;
                        match = 1'b1;
                        cur_r0 = key_r0;
                        cur_r1 = key_r1;

                        for (int i = 0; i < PREFIX_LEN; i++) begin
                            if (decode_byte(msg_mem[i], cur_r0, cur_r1, key_ref) != PREFIX[i]) begin
                                match = 1'b0;
                                break;
                            end
                            // Avance de rotores (Youngest cada paso, segundo cada 10 pasos)
                            cur_r0 = (cur_r0 + 1'b1) % 128;
                            if ((i + 1) % 10 == 0) begin
                                cur_r1 = (cur_r1 + 1'b1) % 128;
                            end
                        end

                        if (match) begin
                            // Clave encontrada, pasar a la salida
                            rot0   <= key_r0;
                            rot1   <= key_r1;
                            tx_cnt <= '0;
                            state  <= ST_STREAM_OUT;
                        end else begin
                            state <= ST_ADVANCE_KEY;
                        end
                    end else begin
                        state <= ST_ADVANCE_KEY;
                    end
                end

                ST_ADVANCE_KEY: begin
                    // Incrementar el espacio de claves de 7 bits (0 a 127)
                    if (key_r0 == 7'd127) begin
                        key_r0 <= '0;
                        if (key_r1 == 7'd127) begin
                            key_r1 <= '0;
                            key_ref <= key_ref + 1'b1;
                        end else begin
                            key_r1 <= key_r1 + 1'b1;
                        end
                    end else begin
                        key_r0 <= key_r0 + 1'b1;
                    end
                    state <= ST_CHECK_KEY;
                end

                ST_STREAM_OUT: begin
                    if (tx_cnt < msg_length) begin
                        o_valid <= 1'b1;
                        o_data  <= decode_byte(msg_mem[tx_cnt], rot0, rot1, key_ref);
                        o_last  <= (tx_cnt == msg_length - 1'b1);
                        
                        // Actualizar avance de rotores en la transmisión
                        rot0 <= (rot0 + 1'b1) % 128;
                        if ((tx_cnt + 1'b1) % 10 == 0) begin
                            rot1 <= (rot1 + 1'b1) % 128;
                        end
                        
                        tx_cnt <= tx_cnt + 1'b1;
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