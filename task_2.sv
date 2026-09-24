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

  // always@(posedge i_clk) begin
  //   o_data  <= i_data;  // Just a dummy assignement. Replace with your code.
  //   o_valid <= i_valid; // Just a dummy assignement. Replace with your code.
  //   o_last  <= i_last;  // Just a dummy assignement. Replace with your code.
  // end


    typedef enum logic [1:0] {
        ST_A,
        ST_B,
        ST_C,
        ST_D
    } state_t;

    state_t state, next_state;

    logic [9:0] delay_cnt;

    // logic signed [15:0] data_mem [1024];
    // logic signed [15:0] max_value ;

    logic signed [TASK_INPUT_WIDTH-1:0] max_value;
    logic signed [TASK_INPUT_WIDTH-1:0] data_mem [0:1023];


    // Registro de estado
    always_ff @(posedge i_clk) begin
        if (i_rst)
            state <= ST_A;
        else
            state <= next_state;
    end

    // Contador: en ST_B es el índice de memoria; en ST_D cuenta la espera.
    always_ff @(posedge i_clk) begin
        if (i_rst)
            delay_cnt <= 10'd0;
        else begin

            case (state)

                // input first
                ST_A: begin
                    
                    if (i_first  == 1'b1 && i_valid == 1'b1) begin
                        next_state = ST_B;
                        x_max <= i_data;
                    end
                end

                ST_B: begin
                    
                    if (i_valid == 1'b1) begin
                        next_state = ST_C;
                        y_max <= i_data;
                    end
                end

                ST_C: begin
                    
                    if (i_valid == 1'b1) begin
                        if (x + 1 <= x_max) begin
                            next_state = ST_DERECHA;
                            X = X + 1;
                        end else begin
                            next_state = ST_ABAJO
                            Y = Y + 1;
                        end
                        data[0][0] <= i_data;
                    end
                end

                ST_DERECHA: begin
                    
                    if (i_valid == 1'b1) begin
                        if (y + 1 <= y_max) begin
                            next_state = ST_IZQ_ABAJO;
                            X = X - 1;
                            Y = Y + 1;
                        end else begin
                            next_state = ST_DERECHA
                            X = X + 1;
                        end
                        data[0][0] <= i_data;
                    end
                end

                ST_IZQ_ABAJO: begin
                    
                    if (i_valid == 1'b1) begin
                        if (y + 1 <= y_max) begin
                            next_state = ST_ABAJO;
                            Y = Y + 1;
                        end else begin
                            next_state = ST_DERECHA
                            X = X + 1;
                        end
                        data[0][0] <= i_data;
                    end
                end

                ST_ABAJO: begin
                    
                    if (i_valid == 1'b1) begin
                        next_state = ST_ARRIBA_DERECHA;
                        X = X + 1;
                        Y = Y - 1;
                            
                    end
                end

                ST_ARRIBA_DERECHA: begin
                    
                    if (i_valid == 1'b1) begin
                        
                        if (X + 1 <= X_max) begin
                            next_state = ST_ARRIBA_DERECHA;
                            X = X + 1;
                            Y = Y - 1;
                        end else begin
                            next_state = ST_ABAJO
                            Y = Y + 1;
                        end
                            
                    end
                end

                ST_ABAJO: begin
                    
                    if (i_valid == 1'b1) begin
                        if (Y + 1 <= Y_max) begin
                            next_state = ST_ARRIBA_DERECHA;
                            X = X - 1;
                            Y = Y + 1;
                        end else begin
                            next_state = ST_ABAJO
                            Y = Y + 1;
                        end
                            
                    end
                end



                // input loop 
                ST_B: begin
                    
                    if (i_valid) begin
                        if (i_last)
                            next_state = ST_C;
                    end
                end

                // compare la ultima plsi 
                // output
                ST_C: begin 
                    // En always_comb se usa =; <= se reserva para always_ff.
                    o_valid  = 1'b1;
                    o_last   = 1'b1;
                    o_data   = max_value;
                    next_state = ST_D;
                end

                ST_D: begin 
                    if (delay_cnt == 10'd10)
                        next_state = ST_A;
                end

                default:
                    next_state = ST_A;

            endcase

            case (state)


                ST_A: 
                    if (i_valid && i_first) begin
                        x_max <= i_data;
                    end
                ST_B: 
                    if (i_valid && i_first) begin
                        x_max <= i_data;
                    end
                ST_B: begin
                    if (i_valid && i_last)
                        delay_cnt <= 10'd0;
                    else if (i_valid)
                        delay_cnt <= delay_cnt + 10'd1;
                end
                ST_C: delay_cnt <= 10'd0;
                ST_D: delay_cnt <= delay_cnt + 10'd1;
                default: delay_cnt <= 10'd0;



                ST_A: delay_cnt <= (i_valid && i_first) ? 10'd1 : 10'd0;
                ST_B: begin
                    if (i_valid && i_last)
                        delay_cnt <= 10'd0;
                    else if (i_valid)
                        delay_cnt <= delay_cnt + 10'd1;
                end
                ST_C: delay_cnt <= 10'd0;
                ST_D: delay_cnt <= delay_cnt + 10'd1;
                default: delay_cnt <= 10'd0;
            endcase
        end
    end

    // BLOQUE SECUENCIAL: memoria y máximo se guardan con el reloj.
    // MAL: actualizar data_mem o max_value dentro de always_comb.
    always_ff @(posedge i_clk) begin
        if (i_rst)
            max_value <= {1'b1, {(TASK_INPUT_WIDTH-1){1'b0}}};
        if (state == ST_A) begin
            max_value <= {1'b1, {(TASK_INPUT_WIDTH-1){1'b0}}};
        end else if (state == ST_A && i_valid && i_first) begin
            data_mem[0] <= i_data;
            max_value <= i_data;
        end else if (state == ST_B && i_valid) begin
            data_mem[delay_cnt] <= i_data;
            if (i_data > max_value)
                max_value <= i_data;
        end
    end

    // Lógica de transición
    always_comb begin

        next_state = state;
        // Valores por defecto: evitan que las salidas retengan valores previos.
        o_valid = 1'b0;
        o_last  = 1'b0;
        o_data  = '0;

        case (state)

            // input first
            ST_A: begin
                
                if (i_first  == 1'b1 && i_valid == 1'b1) begin
                    next_state = ST_B;
                end
            end

            // input loop 
            ST_B: begin
                
                if (i_valid) begin
                    if (i_last)
                        next_state = ST_C;
                end
            end

            // compare la ultima plsi 
            // output
            ST_C: begin 
                // En always_comb se usa =; <= se reserva para always_ff.
                o_valid  = 1'b1;
                o_last   = 1'b1;
                o_data   = max_value;
                next_state = ST_D;
            end

            ST_D: begin 
                if (delay_cnt == 10'd10)
                    next_state = ST_A;
            end

            default:
                next_state = ST_A;

        endcase
    end

endmodule
