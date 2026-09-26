`timescale 1ns / 1ps

module task_12 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8
)(
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

    // Buffer de entrada en BRAM para reducir LUTs/FFs
    (* ram_style = "block" *) logic [7:0] in_buffer [0:4095];
    logic [12:0] in_count;
    logic signed [12:0] idx;

    // Buffer de salida
    logic [7:0] out_buffer [0:127];
    logic [6:0] out_len;
    logic [6:0] out_ptr;

    // PN Stack ajustado
    logic signed [31:0] stack [0:15];
    logic [3:0] sp;

    // Estados FSM
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RX,
        ST_EVAL_STEP,
        ST_FORMAT_INIT,
        ST_FORMAT_STEP,
        ST_TX
    } state_t;

    state_t state;

    logic signed [31:0] op1, op2, res;
    logic               eval_error;
    integer             curr_val, next_val;

    function automatic integer get_roman_value(input logic [7:0] c);
        case (c)
            "I": return 1;
            "V": return 5;
            "X": return 10;
            "L": return 50;
            "C": return 100;
            "D": return 500;
            "M": return 1000;
            "A": return 5000;
            "G": return 10000;
            "P": return 50000;
            "F": return 100000;
            default: return 0;
        endcase
    endfunction

    function automatic logic is_operator(input logic [7:0] c);
        return (c == "+" || c == "-" || c == "*");
    endfunction

    function automatic logic is_space(input logic [7:0] c);
        return (c == " " || c == 8'h09 || c == 8'h0D || c == 8'h0A);
    endfunction

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state      <= ST_IDLE;
            in_count   <= '0;
            out_len    <= '0;
            out_ptr    <= '0;
            o_valid    <= 1'b0;
            o_last     <= 1'b0;
            o_data     <= '0;
            eval_error <= 1'b0;
            sp         <= '0;
            idx        <= '0;
            res        <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    o_valid    <= 1'b0;
                    o_last     <= 1'b0;
                    in_count   <= '0;
                    eval_error <= 1'b0;
                    sp         <= '0;

                    if (i_valid && i_first) begin
                        in_buffer[0] <= i_data;
                        in_count     <= 13'd1;
                        if (i_last) begin
                            idx   <= 13'd0;
                            state <= ST_EVAL_STEP;
                        end else begin
                            state <= ST_RX;
                        end
                    end
                end

                ST_RX: begin
                    if (i_valid) begin
                        in_buffer[in_count] <= i_data;
                        in_count            <= in_count + 1'b1;
                        if (i_last) begin
                            idx   <= in_count;
                            state <= ST_EVAL_STEP;
                        end
                    end
                end

                ST_EVAL_STEP: begin
                    if (idx >= 0 && !eval_error) begin
                        if (is_space(in_buffer[idx])) begin
                            idx <= idx - 13'sd1;
                        end
                        else if (is_operator(in_buffer[idx])) begin
                            if (sp < 2) begin
                                eval_error <= 1'b1;
                            end else begin
                                op1 = stack[sp-1];
                                op2 = stack[sp-2];
                                sp  = sp - 1'b1;

                                case (in_buffer[idx])
                                    "+": res = op1 + op2;
                                    "-": res = op1 - op2;
                                    "*": res = op1 * op2;
                                    default: res = 0;
                                endcase

                                if (res < 1 || res > 32'sd1399999) begin
                                    eval_error <= 1'b1;
                                end else begin
                                    stack[sp-1] <= res;
                                end
                            end
                            idx <= idx - 13'sd1;
                        end
                        else begin
                            curr_val = get_roman_value(in_buffer[idx]);
                            if (curr_val == 0) begin
                                eval_error <= 1'b1;
                            end else begin
                                if (idx < in_count - 1) begin
                                    next_val = get_roman_value(in_buffer[idx+1]);
                                    if (curr_val < next_val)
                                        curr_val = -curr_val;
                                end

                                if (sp > 0 && idx < in_count - 1 && !is_space(in_buffer[idx+1]) && !is_operator(in_buffer[idx+1])) begin
                                    stack[sp-1] <= stack[sp-1] + curr_val;
                                end else begin
                                    stack[sp] <= curr_val;
                                    sp        <= sp + 1'b1;
                                end
                            end
                            idx <= idx - 13'sd1;
                        end
                    end else begin
                        if (sp != 1) eval_error <= 1'b1;
                        state <= ST_FORMAT_INIT;
                    end
                end

                ST_FORMAT_INIT: begin
                    out_len <= '0;
                    if (eval_error) begin
                        out_buffer[0] <= "e";
                        out_buffer[1] <= "r";
                        out_buffer[2] <= "r";
                        out_buffer[3] <= "o";
                        out_buffer[4] <= "r";
                        out_len       <= 7'd5;
                        out_ptr       <= '0;
                        state         <= ST_TX;
                    end else begin
                        res   <= stack[0];
                        state <= ST_FORMAT_STEP;
                    end
                end

                // Conversión secuencial paso a paso (sin bucles 'while')
                ST_FORMAT_STEP: begin
                    if (res >= 100000)      begin out_buffer[out_len] <= "F"; out_len <= out_len + 1'b1; res <= res - 100000; end
                    else if (res >= 90000)  begin out_buffer[out_len] <= "M"; out_buffer[out_len+1'b1] <= "F"; out_len <= out_len + 2'd2; res <= res - 90000; end
                    else if (res >= 50000)  begin out_buffer[out_len] <= "P"; out_len <= out_len + 1'b1; res <= res - 50000; end
                    else if (res >= 40000)  begin out_buffer[out_len] <= "M"; out_buffer[out_len+1'b1] <= "P"; out_len <= out_len + 2'd2; res <= res - 40000; end
                    else if (res >= 10000)  begin out_buffer[out_len] <= "G"; out_len <= out_len + 1'b1; res <= res - 10000; end
                    else if (res >= 9000)   begin out_buffer[out_len] <= "M"; out_buffer[out_len+1'b1] <= "G"; out_len <= out_len + 2'd2; res <= res - 9000; end
                    else if (res >= 5000)   begin out_buffer[out_len] <= "A"; out_len <= out_len + 1'b1; res <= res - 5000; end
                    else if (res >= 4000)   begin out_buffer[out_len] <= "M"; out_buffer[out_len+1'b1] <= "A"; out_len <= out_len + 2'd2; res <= res - 4000; end
                    else if (res >= 1000)   begin out_buffer[out_len] <= "M"; out_len <= out_len + 1'b1; res <= res - 1000; end
                    else if (res >= 900)    begin out_buffer[out_len] <= "C"; out_buffer[out_len+1'b1] <= "M"; out_len <= out_len + 2'd2; res <= res - 900; end
                    else if (res >= 500)    begin out_buffer[out_len] <= "D"; out_len <= out_len + 1'b1; res <= res - 500; end
                    else if (res >= 400)    begin out_buffer[out_len] <= "C"; out_buffer[out_len+1'b1] <= "D"; out_len <= out_len + 2'd2; res <= res - 400; end
                    else if (res >= 100)    begin out_buffer[out_len] <= "C"; out_len <= out_len + 1'b1; res <= res - 100; end
                    else if (res >= 90)     begin out_buffer[out_len] <= "X"; out_buffer[out_len+1'b1] <= "C"; out_len <= out_len + 2'd2; res <= res - 90; end
                    else if (res >= 50)     begin out_buffer[out_len] <= "L"; out_len <= out_len + 1'b1; res <= res - 50; end
                    else if (res >= 40)     begin out_buffer[out_len] <= "X"; out_buffer[out_len+1'b1] <= "L"; out_len <= out_len + 2'd2; res <= res - 40; end
                    else if (res >= 10)     begin out_buffer[out_len] <= "X"; out_len <= out_len + 1'b1; res <= res - 10; end
                    else if (res >= 9)      begin out_buffer[out_len] <= "I"; out_buffer[out_len+1'b1] <= "X"; out_len <= out_len + 2'd2; res <= res - 9; end
                    else if (res >= 5)      begin out_buffer[out_len] <= "V"; out_len <= out_len + 1'b1; res <= res - 5; end
                    else if (res >= 4)      begin out_buffer[out_len] <= "I"; out_buffer[out_len+1'b1] <= "V"; out_len <= out_len + 2'd2; res <= res - 4; end
                    else if (res >= 1)      begin out_buffer[out_len] <= "I"; out_len <= out_len + 1'b1; res <= res - 1; end
                    else begin
                        out_ptr <= '0;
                        state   <= ST_TX;
                    end
                end

                ST_TX: begin
                    if (out_ptr < out_len) begin
                        o_valid <= 1'b1;
                        o_data  <= out_buffer[out_ptr];
                        o_last  <= (out_ptr == out_len - 1'b1);
                        out_ptr <= out_ptr + 1'b1;
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