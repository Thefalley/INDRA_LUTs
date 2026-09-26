`timescale 1ns / 1ps

module task_2 (
    input  wire        i_clk,
    input  wire        i_rst,

    input  wire        i_valid,
    input  wire        i_first,
    input  wire        i_last,
    input  wire [15:0] i_data [0:1], // i_data[0] = v[n], i_data[1] = t[n]

    output logic       o_valid,
    output logic       o_last,
    output logic [31:0] o_data
);

    // Header para el formato Q1.15 especificado en la tabla de la tarea
    localparam logic [31:0] HEADER_Q1_15 = 32'h01007171;

    // Coeficientes de calibración en punto fijo (32 bits Q1.15)
    // Ajustados para que las operaciones se asignen a DSP48s
    localparam signed [15:0] CAL_ALPHA = 16'sd32767; // Ganancia/Escala (1.0 en Q1.15)
    localparam signed [15:0] CAL_BETA  = 16'sd0;     // Coeficiente de compensación de temp

    // Señales internas
    wire signed [15:0] v_sample = signed'(i_data[0]);
    wire signed [15:0] t_sample = signed'(i_data[1]);

    // Registros de Pipeline (Mínima latencia: 1 ciclo de reloj)
    logic        header_active;
    logic        pipe_valid;
    logic        pipe_last;
    logic [31:0] pipe_data;

    // Módulos aritméticos que se mapean a DSP48
    logic signed [31:0] prod_v;
    logic signed [31:0] prod_t;
    logic signed [31:0] m_corrected;

    always_comb begin
        prod_v      = v_sample * CAL_ALPHA;
        prod_t      = t_sample * CAL_BETA;
        m_corrected = prod_v - prod_t;
    end

    // FSM de control de salida streaming
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            header_active <= 1'b0;
            pipe_valid    <= 1'b0;
            pipe_last     <= 1'b0;
            pipe_data     <= '0;
            o_valid       <= 1'b0;
            o_last        <= 1'b0;
            o_data        <= '0;
        end else begin
            if (i_valid) begin
                if (i_first && !header_active) begin
                    // Emitir HEADER inmediatamente al recibir el primer dato
                    o_valid       <= 1'b1;
                    o_data        <= HEADER_Q1_15;
                    o_last        <= 1'b0;
                    header_active <= 1'b1;

                    // Almacenar en pipeline la muestra actual para el siguiente ciclo
                    pipe_valid    <= 1'b1;
                    pipe_last     <= i_last;
                    pipe_data     <= m_corrected;
                end else if (header_active && pipe_valid) begin
                    // Transmisión en pipeline sostenida
                    o_valid       <= 1'b1;
                    o_data        <= pipe_data;
                    o_last        <= 1'b0;

                    pipe_valid    <= 1'b1;
                    pipe_last     <= i_last;
                    pipe_data     <= m_corrected;
                end else begin
                    o_valid       <= 1'b1;
                    o_data        <= m_corrected;
                    o_last        <= i_last;
                    pipe_valid    <= 1'b0;
                end
            end else if (pipe_valid) begin
                // Vaciar la última muestra que quedó retenida por la inserción del header
                o_valid    <= 1'b1;
                o_data     <= pipe_data;
                o_last     <= pipe_last;
                pipe_valid <= 1'b0;

                if (pipe_last) begin
                    header_active <= 1'b0;
                end
            end else begin
                o_valid <= 1'b0;
                o_last  <= 1 meb0; // Resetea flags de salida
                if (i_last) begin
                    header_active <= 1'b0;
                end
            end
        end
    end

endmodule