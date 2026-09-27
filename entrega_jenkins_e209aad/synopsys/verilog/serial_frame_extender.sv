`timescale 1ns/1ps

// File: serial_frame_extender.sv
// Purpose: receive a continuous 8 Mbit/s serial input stream,
//          identifies the bit position of a single '1' bit within each frame,
//          and outputs an extended frame containing the original 128 bit data followed
//          by an 8 bit binary representation of the detected bit position.
// Notes  : Input sampling occurs on rising edge of in_clk; output data
//          changes on falling edge of out_clk and is sampled on out_clk rising.
//          Max latency from input to output should be < 2 frames.

module serial_frame_extender #(
  parameter int unsigned FRAME_START_MSB_FIRST = 8'h4E,  // 0100_1110[cite: 7]
  parameter int unsigned START_LSBF            = 8'h72
) (
  input  logic clk64,    // Reloj del sistema a 64 MHz[cite: 7]
  input  logic rst_n,    // Reset asíncrono activo en bajo[cite: 7]
  // Interfaz de entrada serial
  input  logic in_clk,   // ~8 MHz, muestreo en flanco de subida[cite: 7]
  input  logic in_data,  // Entrada de datos[cite: 7]
  // Interfaz de salida serial
  output logic out_clk,  // Reloj derivado continuo[cite: 7]
  output logic out_data  // Cambia en flanco de bajada de out_clk[cite: 7]
);

  localparam logic [7:0] FRAME_START = FRAME_START_MSB_FIRST[7:0]; // 0x4E[cite: 7]

  //--------------------------------------------------------------------------
  // 1. RECEPCIÓN Y ALMACENAMIENTO (Dominio in_clk)
  //--------------------------------------------------------------------------
  logic [135:0] frame_mem [0:1]; // Buffers Ping-Pong (128 bits datos + 8 bits posición)[cite: 7]
  logic         write_bank;
  
  logic [7:0]   header_shift;
  logic [127:0] rx_frame;
  logic [7:0]   detected_index;
  logic [6:0]   payload_index;
  logic         collecting;

  always_ff @(posedge in_clk or negedge rst_n) begin
    if (!rst_n) begin
      header_shift   <= 8'd0;
      rx_frame       <= 128'd0;
      detected_index <= 8'd0;
      payload_index  <= 7'd0;
      collecting     <= 1'b0;
      write_bank     <= 1'b0;
    end else begin
      if (!collecting) begin
        header_shift <= {header_shift[6:0], in_data};
        if ({header_shift[6:0], in_data} == FRAME_START) begin
          rx_frame       <= {120'd0, FRAME_START};
          detected_index <= 8'd0;
          payload_index  <= 7'd0;
          collecting     <= 1'b1;
        end
      end else begin
        rx_frame <= {rx_frame[126:0], in_data};
        
        if (in_data) begin
          detected_index <= {1'b0, payload_index}; // Posición del bit '1' (0 a 119)[cite: 7]
        end

        if (payload_index == 7'd119) begin
          // Guardar trama original de 128 bits + Posición binaria en MSB-first[cite: 7]
          automatic logic [7:0] final_pos = in_data ? {1'b0, payload_index} : detected_index;
          frame_mem[write_bank] <= {{rx_frame[126:0], in_data}, final_pos};
          write_bank            <= ~write_bank;
          collecting            <= 1'b0;
          header_shift          <= 8'd0;
        end else begin
          payload_index <= payload_index + 1'b1;
        end
      end
    end
  end

  //--------------------------------------------------------------------------
  // 2. GENERACIÓN DE RELOJ DE SALIDA (out_clk @ 8.5 MHz libre)[cite: 7]
  // 136 bits a 8.5 MHz equivalen a exactamente 128 bits a 8 MHz
  //--------------------------------------------------------------------------
  logic [5:0] clock_phase;
  wire  [6:0] next_phase = {1'b0, clock_phase} + 7'd17; // NCO 64MHz * 17 / 128 = 8.5MHz

  always_ff @(posedge clk64 or negedge rst_n) begin
    if (!rst_n) begin
      clock_phase <= 6'd0;
      out_clk     <= 1'b0;
    end else begin
      clock_phase <= next_phase[5:0];
      if (next_phase[6]) begin
        out_clk <= ~out_clk; // Genera pulso out_clk continuo libre[cite: 7]
      end
    end
  end

  // Detectar el flanco de bajada de out_clk en el dominio clk64[cite: 7]
  wire out_clk_falling = next_phase[6] && out_clk;

  //--------------------------------------------------------------------------
  // 3. SINCRONIZACIÓN Y TRANSMISIÓN (Dominio clk64)
  //--------------------------------------------------------------------------
  logic wr_sync_1, wr_sync_2;
  logic tx_active;
  logic tx_seen;
  logic tx_bank;
  logic [7:0] tx_bit_index;

  // Sincronizador CDC para la bandera de escritura entre dominios de reloj
  always_ff @(posedge clk64 or negedge rst_n) begin
    if (!rst_n) begin
      wr_sync_1 <= 1'b0;
      wr_sync_2 <= 1'b0;
    end else begin
      wr_sync_1 <= write_bank;
      wr_sync_2 <= wr_sync_1;
    end
  end

  // Transmisión serial sincronizada al flanco de bajada de out_clk[cite: 7]
  always_ff @(posedge clk64 or negedge rst_n) begin
    if (!rst_n) begin
      tx_active    <= 1'b0;
      tx_seen      <= 1'b0;
      tx_bank      <= 1'b0;
      tx_bit_index <= 8'd0;
      out_data     <= 1'b0;
    end else if (out_clk_falling) begin
      if (!tx_active) begin
        if (wr_sync_2 != tx_seen) begin
          // Iniciar transmisión de la trama completa almacenada
          tx_active    <= 1'b1;
          tx_seen      <= wr_sync_2;
          tx_bank      <= ~wr_sync_2; // Leer el banco completado
          tx_bit_index <= 8'd1;
          out_data     <= frame_mem[~wr_sync_2][135]; // Transmitir MSB primero[cite: 7]
        end else begin
          out_data <= 1'b0;
        end
      end else begin
        out_data <= frame_mem[tx_bank][135 - tx_bit_index];
        if (tx_bit_index == 8'd135) begin
          tx_active <= 1'b0;
        end else begin
          tx_bit_index <= tx_bit_index + 1'b1;
        end
      end
    end
  end

endmodule