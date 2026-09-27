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

  // Estados FSM compactos (3 bits)
  typedef enum logic [2:0] {
    ST_WAIT_CTRL1,
    ST_WAIT_CTRL0,
    ST_STREAM_IN,
    ST_PREP_OUT,
    ST_STREAM_OUT
  } state_t;

  state_t state;

  // Registros de control
  logic        mode_rot;   // 0: Shift, 1: Rotate
  logic        dir_right;  // 0: Left,  1: Right
  logic [13:0] shift_val;

  // Contadores optimizados en ancho de bit exacto (11 bits = 2048 max)
  logic [10:0] wr_ptr;
  logic [10:0] rd_ptr_a;
  logic [10:0] rd_ptr_b;
  logic [10:0] pkt_len;
  logic [10:0] out_cnt;

  logic [2:0]  bit_shift;
  logic [10:0] byte_shift;

  // Datos guardados para el alineador de bits (1 byte de ventana previa)
  logic [7:0]  prev_data;

  // Memoria Distribuida en LUTs (Distributed RAM / SRLs)
  // Forzamos la síntesis a LUTRAM para evitar consumo de BRAMs
  (* ram_style = "distributed" *) logic [7:0] mem [0:2047];

  logic [7:0] mem_out_a;
  logic [7:0] mem_out_b;

  // Lógica de Memoria
  always_ff @(posedge i_clk) begin
    if (i_valid && (state == ST_STREAM_IN)) begin
      mem[wr_ptr] <= i_data;
    end
    mem_out_a <= mem[rd_ptr_a];
    mem_out_b <= mem[rd_ptr_b];
  end

  // Máquina de Estados y Lógica Principal
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state      <= ST_WAIT_CTRL1;
      wr_ptr     <= '0;
      rd_ptr_a   <= '0;
      rd_ptr_b   <= '0;
      pkt_len    <= '0;
      out_cnt    <= '0;
      mode_rot   <= 1'b0;
      dir_right  <= 1'b0;
      shift_val  <= '0;
      bit_shift  <= '0;
      byte_shift <= '0;
      prev_data  <= '0;
      o_valid    <= 1'b0;
      o_last     <= 1'b0;
      o_data     <= '0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        ST_WAIT_CTRL1: begin
          wr_ptr  <= '0;
          out_cnt <= '0;
          if (i_valid && i_first) begin
            mode_rot        <= i_data[7];
            dir_right       <= i_data[6];
            shift_val[13:8] <= i_data[5:0];
            state           <= ST_WAIT_CTRL0;
          end
        end

        ST_WAIT_CTRL0: begin
          if (i_valid) begin
            shift_val[7:0] <= i_data;
            state          <= ST_STREAM_IN;
          end
        end

        ST_STREAM_IN: begin
          if (i_valid) begin
            if (i_last) begin
              pkt_len <= wr_ptr + 1'b1;
              state   <= ST_PREP_OUT;
            end else begin
              wr_ptr <= wr_ptr + 1'b1;
            end
          end
        end

        ST_PREP_OUT: begin
          // Cálculo optimizado del desplazamiento a nivel de byte y bit
          logic [13:0] eff_shift;
          eff_shift = (mode_rot && (pkt_len != 0)) ? (shift_val % ({pkt_len, 3'b000})) : shift_val;

          byte_shift <= eff_shift[13:3];
          bit_shift  <= eff_shift[2:0];

          // Asignación de punteros para lectura paralela
          if (!dir_right) begin // Izquierda
            rd_ptr_a <= eff_shift[13:3] % pkt_len;
            rd_ptr_b <= (eff_shift[13:3] + 1'b1) % pkt_len;
          end else begin        // Derecha
            rd_ptr_a <= (pkt_len > eff_shift[13:3]) ? (pkt_len - eff_shift[13:3]) : '0;
            rd_ptr_b <= (pkt_len > (eff_shift[13:3] + 1'b1)) ? (pkt_len - (eff_shift[13:3] + 1'b1)) : '0;
          end

          out_cnt <= '0;
          state   <= ST_STREAM_OUT;
        end

        ST_STREAM_OUT: begin
          if (out_cnt < pkt_len) begin
            o_valid <= 1'b1;
            out_cnt <= out_cnt + 1'b1;

            if (out_cnt == pkt_len - 1'b1) begin
              o_last <= 1'b1;
              state  <= ST_WAIT_CTRL1;
            end

            // Incremento circular de punteros
            rd_ptr_a <= (rd_ptr_a + 1'b1 == pkt_len) ? 11'd0 : rd_ptr_a + 1'b1;
            rd_ptr_b <= (rd_ptr_b + 1'b1 == pkt_len) ? 11'd0 : rd_ptr_b + 1'b1;

            // Alineamiento de bits con Barrel Shifter combinacional de 1 estadio
            if (!dir_right) begin
              o_data <= ({mem_out_a, mem_out_b} << bit_shift) >> 8;
            end else begin
              o_data <= ({mem_out_b, mem_out_a} >> bit_shift);
            end
          end
        end

        default: state <= ST_WAIT_CTRL1;
      endcase
    end
  end

endmodule