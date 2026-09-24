`timescale 1ns / 1ps
module task_3
#(
  parameter int TASK_INPUT_WIDTH = 8,
  parameter int TASK_OUTPUT_WIDTH = 8,
  parameter int INPUT_STREAMS     = 1,
  parameter int OUTPUT_STREAMS    = 1,
  parameter int N    = 8*8 // 8 memorias por si hay colapso de datos

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

    typedef enum logic [1:0] {
        ST_0,
        ST_1,
        ST_2
    } state_t;

    state_t state, next_state;

    logic [3:0] ventana [0:7];

    logic [7:0] enable;  // enable[0] corresponde a ventana[0], etc.

    logic [2:0] cont;

    logic [7:0] fifo_out[N];

    logic [3:0] w0;

    logic [TASK_INPUT_WIDTH-1:0] data_now;
    logic [TASK_INPUT_WIDTH-1:0] data_next;

    // Registro de estado
    always_ff @(posedge i_clk) begin
        if (i_rst)
            state <= ST_0;
        else
            state <= next_state;
    end

    // Contador: en ST_B es el índice de memoria; en ST_D cuenta la espera.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            data_now  <= 0;
            data_next <= 0;
        end else begin

            case (state)

                // input first
                ST_0: begin
                    data_now <= 0;
                    if (i_first  == 1'b1 && i_valid == 1'b1) begin
                        next_state = ST_1;
                        w0 <= i_data;
                    end
                end

                ST_1: begin
                    if (i_valid == 1'b1) begin
                        data_now <= i_data;
                        data_next <= data_now;
                        if (i_last == 1'b1) begin
                            next_state = ST_2;
                        end  
                    end
                end

                ST_2: begin
                    if (o_valid == 1'b1 && o_last == 1'b1) begin
                        // termina y vuelve a empezar
                        next_state = ST_0;
                    end
                end
                
                default:
                    next_state = ST_0;

            endcase

        end
    end

    always_comb begin
        ventana[0] = {data_next[2:0], data_now[7]};
        ventana[1] = {data_next[1:0], data_now[7:6]};
        ventana[2] = {data_next[0],   data_now[7:5]};
        ventana[3] = data_now[7:4];
        ventana[4] = data_now[6:3];
        ventana[5] = data_now[5:2];
        ventana[6] = data_now[4:1];
        ventana[7] = data_now[3:0];

        for (int i = 0; i < 8; i++) begin
            if (ventana[i] == w0[3:0]) begin
                enable[i] = 1'b1;
            end else begin
                enable[i] = 1'b0;
            end
        end

    end 

    // Registro de estado
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            for (int i = 0; i < 8; i++) begin
                fifo_out[i] <= 0;
            end
        end else begin
            for (int i = 0; i < 8; i++) begin
                if (enable[i] == 1'b1) begin
                    fifo_out[i+cont] <= ventana[i];
                end
            end

        end 
    end

    // Registro de estado
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            cont <= 0;
        end else begin
            if (i_valid == 1'b1 && i_last == 1'b1) begin
                cont <= 0;
            end else if (i_valid == 1'b1 && i_first == 1'b1) begin
                cont <= 1;
            end else if (i_valid == 1'b1) begin
                cont <= cont + 1;
            end
        end 
    end
    
endmodule
