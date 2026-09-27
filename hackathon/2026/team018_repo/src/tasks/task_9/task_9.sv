`timescale 1ns / 1ps

module task_9 #(
  parameter int TASK_INPUT_WIDTH  = 32,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input  wire                         i_clk,
  input  wire                         i_rst,
  input  wire                         i_valid,
  input  wire                         i_first,
  input  wire                         i_last,
  input  wire  [TASK_INPUT_WIDTH-1:0] i_data,
  output logic                        o_valid,
  output logic                        o_first,
  output logic                        o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  localparam int MAX_INPUT_SAMPLES = 2048;

  // Memoria BRAM para almacenamiento de subcracovianas
  (* ram_style = "block" *) logic [31:0] sample_mem [0:MAX_INPUT_SAMPLES-1];

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_RECEIVE,
    ST_CALC_INIT,
    ST_FETCH,
    ST_ACCUMULATE,
    ST_NORMALIZE,
    ST_OUT_CONFIG,
    ST_OUT_DATA
  } state_t;

  state_t state;

  // Registros de Configuración
  logic [7:0]  num_pair;
  logic [5:0]  row_blocks;     // num_rows / 2
  logic [5:0]  col_a_blocks;   // num_col_a / 2
  logic [5:0]  col_b_blocks;   // num_col_b / 2
  logic [11:0] samples_per_pair;
  logic [11:0] receive_count;

  // Punteros de Cálculo
  logic [7:0]  pair_idx;
  logic [5:0]  col_a_idx;
  logic [5:0]  col_b_idx;
  logic [5:0]  k_block_idx;
  logic [11:0] pair_base;

  // Direccionamiento a Memoria
  logic [10:0] addr_a, addr_b;
  logic [31:0] a_sample, b_sample;

  // Mapeo Direcciones para Cracovianas (Columna x Columna / Transpuesta)
  always_comb begin
    // A: Bloque k de la columna col_a_idx
    addr_a = pair_base + col_a_idx * row_blocks + k_block_idx;
    // B: Bloque k de la columna col_b_idx (Acceso pareado por filas/columnas cracovianas)
    addr_b = pair_base + (col_a_blocks * row_blocks) + col_b_idx * row_blocks + k_block_idx;
  end

  // BRAM Synchronous Read
  always_ff @(posedge i_clk) begin
    if (i_valid && (state == ST_RECEIVE)) begin
      sample_mem[receive_count] <= i_data;
    end
    a_sample <= sample_mem[addr_a];
    b_sample <= sample_mem[addr_b];
  end

  // Descomposición de datos 2x2
  logic signed [6:0] a00, a01, a10, a11;
  logic signed [6:0] b00, b01, b10, b11;
  logic [3:0]        exp_a, exp_b;

  assign a11 = a_sample[31:25];
  assign a10 = a_sample[24:18];
  assign a01 = a_sample[17:11];
  assign a00 = a_sample[10:4];
  assign exp_a = a_sample[3:0];

  assign b11 = b_sample[31:25];
  assign b10 = b_sample[24:18];
  assign b01 = b_sample[17:11];
  assign b00 = b_sample[10:4];
  assign exp_b = b_sample[3:0];

  // Acumuladores de Alta Precisión (48-bits con alineación dinámica por exponente)
  logic signed [47:0] acc_00, acc_01, acc_10, acc_11;

  // Bucle Principal de Control y FSM
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state             <= ST_IDLE;
      receive_count     <= '0;
      pair_idx          <= '0;
      col_a_idx         <= '0;
      col_b_idx         <= '0;
      k_block_idx       <= '0;
      pair_base         <= '0;
      acc_00            <= '0;
      acc_01            <= '0;
      acc_10            <= '0;
      acc_11            <= '0;
      o_valid           <= 1'b0;
      o_first           <= 1'b0;
      o_last            <= 1'b0;
      o_data            <= '0;
    end else begin
      o_valid <= 1'b0;
      o_first <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        ST_IDLE: begin
          receive_count <= '0;
          if (i_valid && i_first) begin
            num_pair         <= i_data[31:24];
            row_blocks       <= i_data[23:17]; // num_rows / 2
            col_a_blocks     <= i_data[15:9];  // num_col_a / 2
            col_b_blocks     <= i_data[7:1];   // num_col_b / 2
            samples_per_pair <= i_data[23:17] * (i_data[15:9] + i_data[7:1]);
            state            <= ST_RECEIVE;
          end
        end

        ST_RECEIVE: begin
          if (i_valid) begin
            receive_count <= receive_count + 1'b1;
            if (i_last) begin
              state     <= ST_CALC_INIT;
              pair_idx  <= '0;
              pair_base <= '0;
            end
          end
        end

        ST_CALC_INIT: begin
          col_a_idx   <= '0;
          col_b_idx   <= '0;
          k_block_idx <= '0;
          acc_00      <= '0;
          acc_01      <= '0;
          acc_10      <= '0;
          acc_11      <= '0;
          state       <= ST_FETCH;
        end

        ST_FETCH: begin
          // Ciclo de latencia para registro de BRAM
          state <= ST_ACCUMULATE;
        end

        ST_ACCUMULATE: begin
          // Operación de multiplicación de sub-bloques 2x2
          // C_ij = Suma_k (A_ki * B_kj) -> Cracoviana
          automatic logic [4:0] cur_exp = exp_a + exp_b;
          
          // Multiplicación de mantisas de 7-bit -> 14-bit con extensión de signo a 48-bit
          logic signed [47:0] p00, p01, p10, p11;
          
          p00 = $signed(a00 * b00 + a10 * b00) <<< cur_exp;
          p01 = $signed(a01 * b00 + a11 * b00) <<< cur_exp;
          p10 = $signed(a00 * b01 + a10 * b01) <<< cur_exp;
          p11 = $signed(a01 * b01 + a11 * b01) <<< cur_exp;

          acc_00 <= acc_00 + p00;
          acc_01 <= acc_01 + p01;
          acc_10 <= acc_10 + p10;
          acc_11 <= acc_11 + p11;

          if (k_block_idx == row_blocks - 1'b1) begin
            state <= ST_NORMALIZE;
          end else begin
            k_block_idx <= k_block_idx + 1'b1;
            state       <= ST_FETCH;
          end
        end

        ST_NORMALIZE: begin
          // Buscar el máximo valor absoluto para calcular el exponente común y normalizar
          automatic logic [47:0] max_val;
          automatic logic [5:0]  shift_amount;
          automatic logic signed [47:0] abs_00, abs_01, abs_10, abs_11;

          abs_00 = (acc_00 < 0) ? -acc_00 : acc_00;
          abs_01 = (acc_01 < 0) ? -acc_01 : acc_01;
          abs_10 = (acc_10 < 0) ? -acc_10 : acc_10;
          abs_11 = (acc_11 < 0) ? -acc_11 : acc_11;

          max_val = abs_00 | abs_01 | abs_10 | abs_11;

          // Encontrar MSB para empaquetado a mantisa de 7 bits
          shift_amount = 0;
          for (int i = 47; i >= 6; i--) begin
            if (max_val[i]) begin
              shift_amount = i - 5;
              break;
            end
          end

          // Escalado y empaquetado
          acc_00 <= acc_00 >>> shift_amount;
          acc_01 <= acc_01 >>> shift_amount;
          acc_10 <= acc_10 >>> shift_amount;
          acc_11 <= acc_11 >>> shift_amount;

          if ((pair_idx == 0) && (col_a_idx == 0) && (col_b_idx == 0))
            state <= ST_OUT_CONFIG;
          else
            state <= ST_OUT_DATA;
        end

        ST_OUT_CONFIG: begin
          o_valid <= 1'b1;
          o_first <= 1'b1;
          // CRAC Output: {num_crac, num_rows, 8'd0, num_col}
          o_data  <= {num_pair, (col_a_blocks << 1), 8'd0, (col_b_blocks << 1)};
          state   <= ST_OUT_DATA;
        end

        ST_OUT_DATA: begin
          o_valid <= 1'b1;
          o_data  <= {acc_11[6:0], acc_10[6:0], acc_01[6:0], acc_00[6:0], 4'b0000};

          // Comprobación de terminación de trama
          if ((pair_idx == num_pair - 1'b1) &&
              (col_a_idx == col_a_blocks - 1'b1) &&
              (col_b_idx == col_b_blocks - 1'b1)) begin
            o_last <= 1'b1;
            state  <= ST_IDLE;
          end else begin
            // Avanzar índices
            acc_00 <= '0; acc_01 <= '0; acc_10 <= '0; acc_11 <= '0;
            k_block_idx <= '0;

            if (col_b_idx == col_b_blocks - 1'b1) begin
              col_b_idx <= '0;
              if (col_a_idx == col_a_blocks - 1'b1) begin
                col_a_idx <= '0;
                pair_idx  <= pair_idx + 1'b1;
                pair_base <= pair_base + samples_per_pair;
              end else begin
                col_a_idx <= col_a_idx + 1'b1;
              end
            end else begin
              col_b_idx <= col_b_idx + 1'b1;
            end

            state <= ST_FETCH;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule