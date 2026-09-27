`timescale 1ns / 1ps
module task_2 #(
  parameter int TASK_INPUT_WIDTH  = 16,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input  wire                         i_clk,
  input  wire                         i_rst,
  input  wire                         i_valid,
  input  wire                         i_first,
  input  wire                         i_last,
  input  wire  [TASK_INPUT_WIDTH-1:0] i_data0,
  input  wire  [TASK_INPUT_WIDTH-1:0] i_data1,
  output logic                        o_valid,
  output logic                        o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  localparam logic [31:0] HEADER_Q1_15 = 32'h01007171; // Fixed Point Q1.15

  // Estados FSM compactos
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_CAPTURE,
    ST_HEADER,
    ST_OUTPUT
  } state_t;

  state_t state;

  // Contadores optimizados (11 bits = 2048 palabras)
  logic [10:0] sample_count;
  logic [10:0] output_count;
  logic [10:0] total_samples;

  // Señales de cálculo de corrección y saturación
  logic signed [31:0] correction;
  logic signed [15:0] corrected_sample;

  // Inferencia de RAM Distribuida compacta en LUTs
  (* ram_style = "distributed" *) logic [15:0] sample_mem [0:2047];

  // Cálculo combinacional de la ecuación de calibración
  always_comb begin
    correction = -32'sd1599 - ($signed(i_data0) <<< 6) - ($signed(i_data0) <<< 4) +
                 (($signed(i_data1) * 32'sd23) >>> 5);

    // Saturation Q1.15
    if (correction > 32'sd32767)
      corrected_sample = 16'sh7fff;
    else if (correction < -32'sd32768)
      corrected_sample = 16'sh8000;
    else
      corrected_sample = correction[15:0];
  end

  // Lógica Secuencial y FSM
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state        <= ST_IDLE;
      sample_count <= '0;
      output_count <= '0;
      total_samples<= '0;
      o_valid      <= 1'b0;
      o_last       <= 1'b0;
      o_data       <= '0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        ST_IDLE: begin
          sample_count <= '0;
          output_count <= '0;
          if (i_valid && i_first) begin
            sample_mem[0] <= corrected_sample;
            if (i_last) begin
              total_samples <= 11'd1;
              state         <= ST_HEADER;
            end else begin
              sample_count  <= 11'd1;
              state         <= ST_CAPTURE;
            end
          end
        end

        ST_CAPTURE: begin
          if (i_valid) begin
            sample_mem[sample_count] <= corrected_sample;
            if (i_last) begin
              total_samples <= sample_count + 1'b1;
              state         <= ST_HEADER;
            end else begin
              sample_count  <= sample_count + 1'b1;
            end
          end
        end

        ST_HEADER: begin
          o_valid      <= 1'b1;
          o_data       <= HEADER_Q1_15;
          output_count <= '0;
          state        <= ST_OUTPUT;
        end

        ST_OUTPUT: begin
          o_valid <= 1'b1;
          o_data  <= {{16{sample_mem[output_count][15]}}, sample_mem[output_count]};

          if (output_count == total_samples - 1'b1) begin
            o_last <= 1'b1;
            state  <= ST_IDLE;
          end else begin
            output_count <= output_count + 1'b1;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule