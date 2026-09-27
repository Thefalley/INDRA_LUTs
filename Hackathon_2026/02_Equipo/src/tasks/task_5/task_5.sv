`timescale 1ns / 1ps

module task_5 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8,
    parameter int NUM_OF_ROTORS     = 2,
    parameter int MAX_MSG_LENGTH    = 1024,
    parameter int ALPHABET_SIZE     = 128
) (
    input wire                          i_clk,
    input wire                          i_rst,

    input wire                          i_valid,
    input wire                          i_first,
    input wire                          i_last,
    input wire  [TASK_INPUT_WIDTH-1:0]  i_data,

    output logic                        o_valid,
    output logic                        o_last,
    output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    localparam int PREFIX_LEN = 45;

    // Memoria para el mensaje (Inferencia adecuada de Block RAM)
    (* ram_style = "block" *) logic [7:0] msg_mem [0:MAX_MSG_LENGTH-1];
    logic [10:0] msg_length;
    logic [10:0] rx_cnt;
    logic [$clog2(MAX_MSG_LENGTH)-1:0] mem_rd_addr;
    logic [7:0] mem_rd_data;
    logic [7:0] first_cipher;

    // Registros para la búsqueda
    logic [6:0] key_r0, key_r1, key_ref;
    logic [6:0] cur_r0, cur_r1;
    logic [5:0] check_idx;

    // Sustituto eficiente del modulo % 10
    logic [3:0] mod10_cnt;

    // Rotores para transmisión
    logic [6:0] rot0, rot1;
    logic [10:0] tx_cnt;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_STORE,
        ST_CHECK_INIT,
        ST_CHECK_STEP,
        ST_ADVANCE_KEY,
        ST_STREAM_OUT,
        ST_CHECK_FETCH,
        ST_STREAM_FETCH
    } state_t;

    state_t state;

    always_comb begin
        if (state == ST_STREAM_FETCH || state == ST_STREAM_OUT)
            mem_rd_addr = tx_cnt;
        else
            mem_rd_addr = check_idx;
    end

    always_ff @(posedge i_clk) begin
        mem_rd_data <= msg_mem[mem_rd_addr];
        if (!i_rst && i_valid &&
            ((state == ST_IDLE && i_first) || state == ST_STORE))
            msg_mem[(state == ST_IDLE) ? 0 : rx_cnt] <= i_data;
    end

    function automatic logic [7:0] get_prefix_char(input logic [5:0] idx);
        case (idx)
            6'd0:  get_prefix_char = "H"; 6'd1:  get_prefix_char = "e"; 6'd2:  get_prefix_char = "l";
            6'd3:  get_prefix_char = "l"; 6'd4:  get_prefix_char = "o"; 6'd5:  get_prefix_char = ",";
            6'd6:  get_prefix_char = " "; 6'd7:  get_prefix_char = "F"; 6'd8:  get_prefix_char = "P";
            6'd9:  get_prefix_char = "G"; 6'd10: get_prefix_char = "A"; 6'd11: get_prefix_char = " ";
            6'd12: get_prefix_char = "H"; 6'd13: get_prefix_char = "a"; 6'd14: get_prefix_char = "c";
            6'd15: get_prefix_char = "k"; 6'd16: get_prefix_char = "a"; 6'd17: get_prefix_char = "t";
            6'd18: get_prefix_char = "h"; 6'd19: get_prefix_char = "o"; 6'd20: get_prefix_char = "n";
            6'd21: get_prefix_char = "!"; 6'd22: get_prefix_char = " "; 6'd23: get_prefix_char = "Y";
            6'd24: get_prefix_char = "o"; 6'd25: get_prefix_char = "u"; 6'd26: get_prefix_char = "r";
            6'd27: get_prefix_char = " "; 6'd28: get_prefix_char = "s"; 6'd29: get_prefix_char = "e";
            6'd30: get_prefix_char = "c"; 6'd31: get_prefix_char = "r"; 6'd32: get_prefix_char = "e";
            6'd33: get_prefix_char = "t"; 6'd34: get_prefix_char = " "; 6'd35: get_prefix_char = "m";
            6'd36: get_prefix_char = "e"; 6'd37: get_prefix_char = "s"; 6'd38: get_prefix_char = "s";
            6'd39: get_prefix_char = "a"; 6'd40: get_prefix_char = "g"; 6'd41: get_prefix_char = "e";
            6'd42: get_prefix_char = " "; 6'd43: get_prefix_char = "i"; 6'd44: get_prefix_char = "s";
            default: get_prefix_char = 8'h00;
        endcase
    endfunction

    function automatic logic [7:0] decode_byte(
        input logic [7:0] in_char,
        input logic [6:0] r0,
        input logic [6:0] r1,
        input logic [6:0] ref_pos
    );
        logic [6:0] c;
        c = in_char[6:0];
        c = (c - 7'd1) ^ r0;
        c = (c - 7'd1) ^ r1;
        c = c ^ ref_pos;
        c = (c - 7'd1) ^ r1;
        c = (c - 7'd1) ^ r0;
        return {1'b0, c};
    endfunction

    // The known first plaintext byte determines the reflector uniquely
    // for each rotor pair. Search 128*128 pairs, not 128*128*128 triples.
    // All arithmetic is modulo 128, as in decode_byte.
    function automatic logic [6:0] derive_reflector(
        input logic [7:0] cipher,
        input logic [6:0] r0,
        input logic [6:0] r1
    );
        logic [6:0] from_cipher, from_plain;
        from_cipher = (cipher[6:0] - 7'd1) ^ r0;
        from_cipher = (from_cipher - 7'd1) ^ r1;
        from_plain = (7'd72 ^ r0) + 7'd1; // known prefix starts with H
        from_plain = (from_plain ^ r1) + 7'd1;
        return from_cipher ^ from_plain;
    endfunction

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state      <= ST_IDLE;
            rx_cnt     <= '0;
            tx_cnt     <= '0;
            msg_length <= '0;
            key_r0     <= '0;
            key_r1     <= '0;
            key_ref    <= '0;
            first_cipher <= '0;
            check_idx  <= '0;
            mod10_cnt  <= '0;
            o_valid    <= 1'b0;
            o_last     <= 1'b0;
            o_data     <= '0;
        end else begin
            o_valid <= 1'b0;
            o_last <= 1'b0;
            case (state)
                ST_IDLE: begin
                    o_valid <= 1'b0;
                    o_last  <= 1'b0;
                    if (i_valid && i_first) begin
                        first_cipher <= i_data;
                        rx_cnt     <= 11'd1;
                        state      <= ST_STORE;
                    end
                end

                ST_STORE: begin
                    if (i_valid) begin
                        rx_cnt          <= rx_cnt + 1'b1;
                        if (i_last) begin
                            msg_length <= rx_cnt + 1'b1;
                            key_r0     <= '0;
                            key_r1     <= '0;
                            key_ref    <= '0;
                            state      <= ST_CHECK_INIT;
                        end
                    end
                end

                ST_CHECK_INIT: begin
                    key_ref   <= derive_reflector(first_cipher, key_r0, key_r1);
                    cur_r0    <= key_r0;
                    cur_r1    <= key_r1;
                    check_idx <= '0;
                    mod10_cnt <= '0;
                    state     <= ST_CHECK_FETCH;
                end

                ST_CHECK_FETCH: state <= ST_CHECK_STEP;
                ST_STREAM_FETCH: state <= ST_STREAM_OUT;

                ST_CHECK_STEP: begin
                    if (decode_byte(mem_rd_data, cur_r0, cur_r1, key_ref) == get_prefix_char(check_idx)) begin
                        if (check_idx == PREFIX_LEN - 1) begin
                            rot0      <= key_r0;
                            rot1      <= key_r1;
                            tx_cnt    <= '0;
                            mod10_cnt <= '0;
                            state     <= ST_STREAM_FETCH;
                        end else begin
                            state <= ST_CHECK_FETCH;
                            check_idx <= check_idx + 1'b1;
                            cur_r0    <= cur_r0 + 1'b1;

                            // Reemplazo eficiente de % 10 mediante contador
                            if (mod10_cnt == 4'd9) begin
                                mod10_cnt <= '0;
                                cur_r1    <= cur_r1 + 1'b1;
                            end else begin
                                mod10_cnt <= mod10_cnt + 1'b1;
                            end
                        end
                    end else begin
                        state <= ST_ADVANCE_KEY;
                    end
                end

                ST_ADVANCE_KEY: begin
                    if (key_r0 == 7'd127) begin
                        key_r0 <= '0;
                        if (key_r1 == 7'd127) begin
                            // No key matched the known prefix. Do not loop
                            // forever or transmit an unverified plaintext.
                            key_r1 <= '0;
                        end else begin
                            key_r1 <= key_r1 + 1'b1;
                        end
                    end else begin
                        key_r0 <= key_r0 + 1'b1;
                    end
                    if (key_r0 == 7'd127 && key_r1 == 7'd127)
                        state <= ST_IDLE;
                    else
                        state <= ST_CHECK_INIT;
                end

                ST_STREAM_OUT: begin
                    if (tx_cnt < msg_length) begin
                        o_valid <= 1'b1;
                        o_data  <= decode_byte(mem_rd_data, rot0, rot1, key_ref);
                        o_last  <= (tx_cnt == msg_length - 1'b1);

                        rot0   <= rot0 + 1'b1;
                        tx_cnt <= tx_cnt + 1'b1;
                        state <= ST_STREAM_FETCH;

                        if (mod10_cnt == 4'd9) begin
                            mod10_cnt <= '0;
                            rot1      <= rot1 + 1'b1;
                        end else begin
                            mod10_cnt <= mod10_cnt + 1'b1;
                        end
                    end else begin
                        o_valid <= 1'b0;
                        o_last  <= 1'b0;
                        state   <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
