`timescale 1ns / 1ps
module task_1
#(
  parameter int TASK_INPUT_WIDTH = 16,
  parameter int TASK_OUTPUT_WIDTH = 16,
  parameter int INPUT_STREAMS     = 1,
  parameter int OUTPUT_STREAMS    = 1

)(
  input                               i_clk,
  input                               i_rst,

  input                               i_valid,
  input                               i_first,
  input                               i_last,
  input signed [TASK_INPUT_WIDTH-1:0] i_data,

  output reg                          o_valid,
  output reg                          o_last,
  output reg signed [TASK_OUTPUT_WIDTH-1:0] o_data
);

  always@(posedge i_clk) begin
    o_data  <= i_data;  // Just a dummy assignement. Replace with your code.
    o_valid <= i_valid; // Just a dummy assignement. Replace with your code.
    o_last  <= i_last;  // Just a dummy assignement. Replace with your code.
  end


    typedef enum logic [1:0] {
        ST_A,
        ST_B,
        ST_C
    } state_t;

    state_t state, next_state;

    logic [7:0] delay_cnt;

    logic [1024][15:0] data_mem;
    logic [15:0] max_value;

    // Registro de estado
    always_ff @(posedge i_clk) begin
        if (i_rst)
            state <= ST_A;
        else
            state <= next_state;
    end

    // Contador de delay
    always_ff @(posedge i_clk) begin
        if (i_rst)
            delay_cnt <= 8'd0;
        else if (state != ST_A)
            delay_cnt <= 8'd0;
        else
            delay_cnt <= delay_cnt + 1'b1;
    end

    // Lógica de transición
    always_comb begin

        next_state = state;

        case (state)

            // input first
            ST_A: begin
                
                if (i_first  == b"1" and i_valid == b'1')
                {
                    next_state = ST_B;
                    data_mem [0] <= i_data;
                    max_value    <= i_data;
                }
            end

            // input loop 
            ST_B: begin
                if (max_value < i_data) 
                    max_value <= i_data;
                if (i_valid)
                    data_mem [0] <= i_data;
                
                if (i_last)
                    next_state = ST_C;
            end

            // compare la ultima plsi 
            // output
            ST_C: begin 
                if (delay_cnt == 8'd10)
                    next_state = ST_A;
            end

            default:
                next_state = ST_A;

        endcase
    end

    // Salidas Moore
    always_comb begin

        estado_a = 1'b0;
        estado_b = 1'b0;
        estado_c = 1'b0;

        case (state)
            ST_A: estado_a = 1'b1;
            ST_B: estado_b = 1'b1;
            ST_C: estado_c = 1'b1;
        endcase

    end

endmodule