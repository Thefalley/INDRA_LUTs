`timescale 1ns / 1ps

module task_1 #(
  parameter int TASK_INPUT_WIDTH  = 8,
  parameter int TASK_OUTPUT_WIDTH = 8
)(
  input  wire                         i_clk,
  input  wire                         i_rst,
  input  wire                         i_valid,
  input  wire                         i_first,
  input  wire                         i_last,
  input  wire  [TASK_INPUT_WIDTH-1:0] i_data,
  output logic                        o_valid,
  output logic                        o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  // FSM de 6 estados claros
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_CTRL_0,
    ST_WRITE,
    ST_CALC,
    ST_READ_PRIME,
    ST_STREAM
  } state_t;

  state_t state;

  // Control y Configuración
  logic        mode_rot;     // 0: Shift, 1: Rotate
  logic        dir_right;    // 0: Left,  1: Right
  logic [13:0] shift_val;    // Valor de desplazamiento de 14 bits

  // Contadores con ancho de 13 bits (Soporta hasta 4096 bytes)
  logic [12:0] wr_ptr;
  logic [12:0] pkt_len;
  logic [12:0] out_cnt;

  logic [12:0] rd_ptr_a;
  logic [12:0] rd_ptr_b;

  logic [12:0] byte_shift;
  logic [2:0]  bit_shift;

  // Inferir BRAM dedicada de doble puerto para 4096 bytes (Mínimo consumo de LUTs)
  (* ram_style = "block" *) logic [7:0] ram [0:4095];
  logic [7:0] ram_dout_a;
  logic [7:0] ram_dout_b;

  // Registro de lectura en RAM (Doble Puerto)
  always_ff @(posedge i_clk) begin
    if (i_valid && (state == ST_WRITE)) begin
      ram[wr_ptr] <= i_data;
    end
    ram_dout_a <= ram[rd_ptr_a];
    ram_dout_b <= ram[rd_ptr_b];
  end

  // Detección de rellenado de ceros (Zero Padding) en modo SHIFT
  logic zero_pad_a, zero_pad_b;
  logic zero_pad_a_reg, zero_pad_b_reg;

  // Lógica principal y FSM
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state          <= ST_IDLE;
      wr_ptr         <= '0;
      pkt_len        <= '0;
      out_cnt        <= '0;
      rd_ptr_a       <= '0;
      rd_ptr_b       <= '0;
      mode_rot       <= 1'b0;
      dir_right      <= 1'b0;
      shift_val      <= '0;
      byte_shift     <= '0;
      bit_shift      <= '0;
      zero_pad_a_reg <= 1'b0;
      zero_pad_b_reg <= 1'b0;
      o_valid        <= 1'b0;
      o_last         <= 1'b0;
      o_data         <= '0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      // Pipeline del control de Zero-Padding por el ciclo de latencia de BRAM
      zero_pad_a_reg <= zero_pad_a;
      zero_pad_b_reg <= zero_pad_b;

      case (state)
        ST_IDLE: begin
          wr_ptr  <= '0;
          out_cnt <= '0;
          if (i_valid && i_first) begin
            mode_rot        <= i_data[7];
            dir_right       <= i_data[6];
            shift_val[13:8] <= i_data[5:0];
            state           <= ST_CTRL_0;
          end
        end

        ST_CTRL_0: begin
          if (i_valid) begin
            shift_val[7:0] <= i_data;
            state          <= ST_WRITE;
          end
        end

        ST_WRITE: begin
          if (i_valid) begin
            if (i_last) begin
              pkt_len <= wr_ptr + 1'b1;
              state   <= ST_CALC;
            end else begin
              wr_ptr <= wr_ptr + 1'b1;
            end
          end
        end

        ST_CALC: begin
          // Extraer directamente el desplazamiento a nivel de byte y bit
          byte_shift <= shift_val[13:3];
          bit_shift  <= shift_val[2:0];

          // Asignación inicial de direcciones de lectura según el modo
          if (!dir_right) begin // LEFT SHIFT / ROTATE
            rd_ptr_a <= byte_shift;
            rd_ptr_b <= byte_shift + 1'b1;
          end else begin        // RIGHT SHIFT / ROTATE
            if (byte_shift >= pkt_len) begin
              rd_ptr_a <= '0;
              rd_ptr_b <= '0;
            end else begin
              rd_ptr_a <= (pkt_len - byte_shift - 1'b1);
              rd_ptr_b <= (pkt_len - byte_shift);
            end
          end

          state <= ST_READ_PRIME;
        end

        ST_READ_PRIME: begin
          // Ciclo de Cebado (Prime) para absorber la latencia de 1 ciclo de la BRAM
          out_cnt <= '0;
          state   <= ST_STREAM;
        end

        ST_STREAM: begin
          if (out_cnt < pkt_len) begin
            o_valid <= 1'b1;
            out_cnt <= out_cnt + 1'b1;

            if (out_cnt == pkt_len - 1'b1) begin
              o_last <= 1'b1;
              state  <= ST_IDLE;
            end

            // Incremento de direcciones con lógica de límites / wrap-around
            if (!dir_right) begin // LEFT
              // Puntero A
              if (rd_ptr_a + 1'b1 < pkt_len)
                rd_ptr_a <= rd_ptr_a + 1'b1;
              else
                rd_ptr_a <= mode_rot ? '0 : pkt_len; // Si es shift, apunta fuera del rango para padding

              // Puntero B
              if (rd_ptr_b + 1'b1 < pkt_len)
                rd_ptr_b <= rd_ptr_b + 1'b1;
              else
                rd_ptr_b <= mode_rot ? '0 : pkt_len;
            end else begin // RIGHT
              // Puntero A
              if (rd_ptr_a > 0)
                rd_ptr_a <= rd_ptr_a - 1'b1;
              else
                rd_ptr_a <= mode_rot ? (pkt_len - 1'b1) : pkt_len;

              // Puntero B
              if (rd_ptr_b > 0)
                rd_ptr_b <= rd_ptr_b - 1'b1;
              else
                rd_ptr_b <= mode_rot ? (pkt_len - 1'b1) : pkt_len;
            end

            // Salida de datos con selección de Padding o BRAM
            logic [7:0] val_a, val_b;
            val_a = zero_pad_a_reg ? 8'h00 : ram_dout_a;
            val_b = zero_pad_b_reg ? 8'h00 : ram_dout_b;

            if (!dir_right) begin
              o_data <= ({val_a, val_b} << bit_shift) >> 8;
            end else begin
              o_data <= ({val_b, val_a} >> bit_shift);
            end
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  // Lógica de detección de Padding combinacional para el estado actual de las direcciones
  always_comb begin
    if (!mode_rot) begin // SHIFT MODE
      zero_pad_a = (rd_ptr_a >= pkt_len);
      zero_pad_b = (rd_ptr_b >= pkt_len);
    end else begin       // ROTATE MODE
      zero_pad_a = 1'b0;
      zero_pad_b = 1'b0;
    end
  end

endmodule