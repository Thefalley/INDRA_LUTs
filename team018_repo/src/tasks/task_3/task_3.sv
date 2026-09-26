`timescale 1ns / 1ps
module task_3
#(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8
)(
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

    localparam int MAX_BYTES = 4096;
    // The Morse protocol reserves the input MSB for the direction flag and
    // uses the LSB for a Morse sample.  The remaining bits form the payload.
    localparam int MODE_BIT      = TASK_INPUT_WIDTH - 1;
    localparam int PAYLOAD_WIDTH = TASK_INPUT_WIDTH - 1;

    // Same three-process FSM style as the reference tasks:
    // state register, datapath registers, and combinational control/outputs.
    typedef enum logic [3:0] {ST_WAIT, ST_DEC_FETCH, ST_DECODE, ST_DEC_FINISH, ST_DEC_SPACE,
                              ST_ENC_FETCH, ST_ENC_PREP, ST_ENC_LOOK_FETCH,
                              ST_ENC_LOOK_CHECK, ST_ENC_SYMBOL, ST_ENC_GAP} state_t;
    state_t state, next_state;

    // A single packet buffer.  The attribute prevents accidental LUT-RAM
    // implementation in the Xilinx flow.
    (* ram_style = "block" *) logic [PAYLOAD_WIDTH-1:0] in_mem [0:MAX_BYTES-1];
    logic [12:0] in_count;
    logic morse_input;

    // Decoder registers.  A code bit of 0 denotes a dot and 1 a dash;
    // element zero is stored at bit zero.
    logic [12:0] scan_idx;
    logic [5:0]  dec_code;
    logic [2:0]  dec_len, run_count;
    logic [3:0]  zero_count;
    logic        dec_started, dec_bit;

    // Encoder registers.
    logic [12:0] enc_idx, look_idx;
    logic [5:0]  enc_code;
    logic [2:0]  enc_len, elem_idx, unit_idx;
    logic [3:0]  gap_left;
    logic        enc_has_next, look_saw_space;
    logic [PAYLOAD_WIDTH-1:0] enc_char, look_char;

    function automatic [5:0] morse_code(input logic [PAYLOAD_WIDTH-1:0] c);
        begin
            case (c)
                "A": morse_code=6'd2;  "B": morse_code=6'd1;
                "C": morse_code=6'd5;  "D": morse_code=6'd1;
                "E": morse_code=6'd0;  "F": morse_code=6'd4;
                "G": morse_code=6'd3;  "H": morse_code=6'd0;
                "I": morse_code=6'd0;  "J": morse_code=6'd14;
                "K": morse_code=6'd5;  "L": morse_code=6'd2;
                "M": morse_code=6'd3;  "N": morse_code=6'd1;
                "O": morse_code=6'd7;  "P": morse_code=6'd6;
                "Q": morse_code=6'd11; "R": morse_code=6'd2;
                "S": morse_code=6'd0;  "T": morse_code=6'd1;
                "U": morse_code=6'd4;  "V": morse_code=6'd8;
                "W": morse_code=6'd6;  "X": morse_code=6'd9;
                "Y": morse_code=6'd13; "Z": morse_code=6'd3;
                "0": morse_code=6'd31; "1": morse_code=6'd30;
                "2": morse_code=6'd28; "3": morse_code=6'd24;
                "4": morse_code=6'd16; "5": morse_code=6'd0;
                "6": morse_code=6'd1;  "7": morse_code=6'd3;
                "8": morse_code=6'd7;  "9": morse_code=6'd15;
                ".": morse_code=6'd42; ",": morse_code=6'd51;
                "+": morse_code=6'd10; "-": morse_code=6'd33;
                "?": morse_code=6'd12; "_": morse_code=6'd44;
                "@": morse_code=6'd22;
                default: morse_code=6'd0;
            endcase
        end
    endfunction

    function automatic [2:0] morse_len(input logic [PAYLOAD_WIDTH-1:0] c);
        begin
            case (c)
                "E", "T": morse_len=1;
                "A", "I", "M", "N": morse_len=2;
                "D", "G", "K", "O", "R", "S", "U", "W": morse_len=3;
                "B", "C", "F", "H", "J", "L", "P", "Q", "V", "X", "Y", "Z": morse_len=4;
                "1", "2", "3", "4", "5", "6", "7", "8", "9", "+": morse_len=5;
                "0", ".", ",", "-", "?", "_", "@": morse_len=6;
                default: morse_len=1;
            endcase
        end
    endfunction

    function automatic [6:0] ascii_from_morse(input logic [5:0] code, input logic [2:0] len);
        begin
            ascii_from_morse = "?";
            case ({len,code})
                {3'd1,6'd0}: ascii_from_morse="E"; {3'd1,6'd1}: ascii_from_morse="T";
                {3'd2,6'd2}: ascii_from_morse="A"; {3'd2,6'd1}: ascii_from_morse="N";
                {3'd2,6'd0}: ascii_from_morse="I"; {3'd2,6'd3}: ascii_from_morse="M";
                {3'd3,6'd5}: ascii_from_morse="K"; {3'd3,6'd1}: ascii_from_morse="D";
                {3'd3,6'd3}: ascii_from_morse="G"; {3'd3,6'd7}: ascii_from_morse="O";
                {3'd3,6'd2}: ascii_from_morse="R"; {3'd3,6'd0}: ascii_from_morse="S";
                {3'd3,6'd4}: ascii_from_morse="U"; {3'd3,6'd6}: ascii_from_morse="W";
                {3'd4,6'd1}: ascii_from_morse="B"; {3'd4,6'd5}: ascii_from_morse="C";
                {3'd4,6'd4}: ascii_from_morse="F"; {3'd4,6'd0}: ascii_from_morse="H";
                {3'd4,6'd14}:ascii_from_morse="J"; {3'd4,6'd2}: ascii_from_morse="L";
                {3'd4,6'd6}: ascii_from_morse="P"; {3'd4,6'd11}:ascii_from_morse="Q";
                {3'd4,6'd8}: ascii_from_morse="V"; {3'd4,6'd9}: ascii_from_morse="X";
                {3'd4,6'd13}:ascii_from_morse="Y"; {3'd4,6'd3}: ascii_from_morse="Z";
                {3'd5,6'd31}:ascii_from_morse="0"; {3'd5,6'd30}:ascii_from_morse="1";
                {3'd5,6'd28}:ascii_from_morse="2"; {3'd5,6'd24}:ascii_from_morse="3";
                {3'd5,6'd16}:ascii_from_morse="4"; {3'd5,6'd0}: ascii_from_morse="5";
                {3'd5,6'd1}: ascii_from_morse="6"; {3'd5,6'd3}: ascii_from_morse="7";
                {3'd5,6'd7}: ascii_from_morse="8"; {3'd5,6'd15}:ascii_from_morse="9";
                {3'd5,6'd10}:ascii_from_morse="+";
                {3'd6,6'd42}:ascii_from_morse="."; {3'd6,6'd51}:ascii_from_morse=",";
                {3'd6,6'd33}:ascii_from_morse="-"; {3'd6,6'd12}:ascii_from_morse="?";
                {3'd6,6'd44}:ascii_from_morse="_"; {3'd6,6'd22}:ascii_from_morse="@";
                default: ascii_from_morse="?";
            endcase
        end
    endfunction

    // 1) State register.
    always_ff @(posedge i_clk) begin
        if (i_rst)
            state <= ST_WAIT;
        else
            state <= next_state;
    end

    // 2) Datapath registers and packet memory.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            in_count <= 0; morse_input <= 0;
            scan_idx <= 0; dec_code <= 0; dec_len <= 0; run_count <= 0;
            zero_count <= 0; dec_started <= 0; dec_bit <= 0;
            enc_idx <= 0; look_idx <= 0; enc_code <= 0; enc_len <= 0;
            elem_idx <= 0; unit_idx <= 0; gap_left <= 0;
            enc_has_next <= 0; look_saw_space <= 0; enc_char <= 0; look_char <= 0;
        end else begin
            case (state)
                ST_WAIT: if (i_valid) begin
                    if (i_first) begin
                        in_count <= 1;
                        in_mem[0] <= i_data[PAYLOAD_WIDTH-1:0];
                        morse_input <= i_data[MODE_BIT];
                    end else if (in_count < MAX_BYTES) begin
                        in_mem[in_count] <= i_data[PAYLOAD_WIDTH-1:0];
                        in_count <= in_count + 1'b1;
                    end
                    if (i_last && (i_first ? i_data[MODE_BIT] : morse_input)) begin
                        scan_idx <= 0; dec_code <= 0; dec_len <= 0;
                        run_count <= 0; zero_count <= 0; dec_started <= 0;
                    end else if (i_last) begin
                        enc_idx <= 0;
                    end
                end

                ST_DEC_FETCH: dec_bit <= in_mem[scan_idx][0];

                ST_DECODE: begin
                    if (dec_bit) begin
                        if (!dec_started) begin
                            dec_started <= 1; run_count <= 1; zero_count <= 0;
                        end else begin
                            if (run_count == 0) begin
                                if (zero_count == 3 || zero_count >= 7) begin
                                    dec_code <= 0;
                                    dec_len <= 0;
                                end
                                zero_count <= 0;
                            end
                            run_count <= run_count + 1'b1;
                        end
                    end else if (dec_started) begin
                        if (run_count != 0) begin
                            dec_code[dec_len] <= (run_count >= 2);
                            dec_len <= dec_len + 1'b1;
                            run_count <= 0;
                            zero_count <= 1;
                        end else if (zero_count < 15) begin
                            zero_count <= zero_count + 1'b1;
                        end
                    end
                    if (scan_idx != in_count-1'b1)
                        scan_idx <= scan_idx + 1'b1;
                end

                ST_DEC_FINISH: in_count <= 0;
                ST_DEC_SPACE: begin end

                // One synchronous-style memory access per clock; no 4096-way search.
                ST_ENC_FETCH: if (enc_idx < in_count)
                    enc_char <= in_mem[enc_idx];

                ST_ENC_PREP: begin
                    if (enc_char == " ") begin
                        enc_idx <= enc_idx + 1'b1;
                    end else begin
                        enc_code <= morse_code(enc_char);
                        enc_len <= morse_len(enc_char);
                        elem_idx <= 0;
                        unit_idx <= 0;
                        look_idx <= enc_idx + 1'b1;
                        look_saw_space <= 0;
                    end
                end

                ST_ENC_LOOK_FETCH: begin
                    if (look_idx < in_count)
                        look_char <= in_mem[look_idx];
                    else
                        enc_has_next <= 0;
                end

                ST_ENC_LOOK_CHECK: begin
                    if (look_char == " ") begin
                        look_saw_space <= 1;
                        look_idx <= look_idx + 1'b1;
                    end else begin
                        enc_has_next <= 1;
                        enc_idx <= look_idx;
                        gap_left <= look_saw_space ? 7 : 3;
                    end
                end

                ST_ENC_SYMBOL: begin
                    if (unit_idx < (enc_code[elem_idx] ? 3 : 1)) begin
                        if (unit_idx == (enc_code[elem_idx] ? 2 : 0)) begin
                            if (elem_idx != enc_len-1'b1)
                                unit_idx <= unit_idx + 1'b1;
                            else if (!enc_has_next)
                                in_count <= 0;
                        end else begin
                            unit_idx <= unit_idx + 1'b1;
                        end
                    end else begin
                        elem_idx <= elem_idx + 1'b1;
                        unit_idx <= 0;
                    end
                end

                ST_ENC_GAP: if (gap_left != 1)
                    gap_left <= gap_left - 1'b1;
                default: in_count <= 0;
            endcase
        end
    end

    // 3) Combinational control and output interface.
    always_comb begin
        next_state = state;
        o_valid = 1'b0;
        o_last  = 1'b0;
        o_data  = 8'd0;

        case (state)
            ST_WAIT: begin
                if (i_valid && i_last)
                    next_state = (i_first ? i_data[MODE_BIT] : morse_input) ? ST_DEC_FETCH : ST_ENC_FETCH;
            end
            ST_DEC_FETCH: next_state = ST_DECODE;
            ST_DECODE: begin
                // A new one after 3/7 zeroes ends the preceding ASCII letter.
                if (dec_started && (run_count == 0) && dec_bit && zero_count >= 3) begin
                    o_valid = 1'b1;
                    o_data = ascii_from_morse(dec_code, dec_len);
                end
                if (dec_started && (run_count == 0) && dec_bit && zero_count >= 7)
                    next_state = ST_DEC_SPACE;
                else if (scan_idx == in_count-1'b1)
                    next_state = ST_DEC_FINISH;
                else
                    next_state = ST_DEC_FETCH;
            end
            ST_DEC_FINISH: begin
                // The final pulse is flushed here; trailing zeroes created no output.
                o_valid = dec_started && (dec_len != 0 || run_count != 0);
                if (run_count != 0)
                    o_data = ascii_from_morse(
                        dec_code | ({5'd0, (run_count >= 2)} << dec_len), dec_len + 1'b1);
                else
                    o_data = ascii_from_morse(dec_code, dec_len);
                o_last = o_valid;
                next_state = ST_WAIT;
            end
            ST_DEC_SPACE: begin
                o_valid = 1'b1;
                o_data = " ";
                next_state = ST_DEC_FETCH;
            end

            ST_ENC_FETCH: begin
                if (enc_idx >= in_count)
                    next_state = ST_WAIT;
                else
                    next_state = ST_ENC_PREP;
            end
            ST_ENC_PREP: begin
                if (enc_char == " ")
                    next_state = ST_ENC_FETCH;
                else
                    next_state = ST_ENC_LOOK_FETCH;
            end
            ST_ENC_LOOK_FETCH: begin
                if (look_idx >= in_count)
                    next_state = ST_ENC_SYMBOL;
                else
                    next_state = ST_ENC_LOOK_CHECK;
            end
            ST_ENC_LOOK_CHECK: begin
                if (look_char == " ")
                    next_state = ST_ENC_LOOK_FETCH;
                else
                    next_state = ST_ENC_SYMBOL;
            end
            ST_ENC_SYMBOL: begin
                o_valid = 1'b1;
                o_data = (unit_idx < (enc_code[elem_idx] ? 3 : 1)) ? 'd1 : '0;
                o_last = !enc_has_next && (elem_idx == enc_len-1'b1) &&
                         (unit_idx == (enc_code[elem_idx] ? 2 : 0));
                if (o_last)
                    next_state = ST_WAIT;
                else if ((unit_idx == (enc_code[elem_idx] ? 2 : 0)) &&
                         (elem_idx == enc_len-1'b1) && enc_has_next)
                    next_state = ST_ENC_GAP;
            end
            ST_ENC_GAP: begin
                o_valid = 1'b1;
                o_data = '0;
                if (gap_left == 1)
                    next_state = ST_ENC_FETCH;
            end
            default: next_state = ST_WAIT;
        endcase
    end
endmodule

