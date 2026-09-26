`timescale 1ns / 1ps

module task_14 #(
    parameter int TASK_INPUT_WIDTH  = 16,
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

    // Memorias BRAM
    (* ram_style = "block" *) logic [15:0] prog_mem [0:512];
    (* ram_style = "block" *) logic [7:0]  data_mem [0:1023];

    typedef enum logic [2:0] {
        ST_LOAD,
        ST_FETCH,
        ST_EXEC,
        ST_DUMP_PREP,
        ST_DUMP
    } state_t;

    state_t state;

    // Registros del procesador
    logic [8:0]  pc;
    logic [9:0]  dump_addr;
    logic [10:0] load_byte_cnt;
    logic [7:0]  r0, r1;
    logic        carry;
    logic [15:0] instr;
    logic [7:0]  low_byte;

    // Decodificación
    logic [4:0]  opcode;
    logic        rx_sel, ry_sel;
    logic [9:0]  addr_imm10;
    logic [7:0]  imm8;

    assign opcode     = instr[15:11];
    assign rx_sel     = instr[10];
    assign ry_sel     = instr[9];
    assign addr_imm10 = instr[9:0];
    assign imm8       = instr[7:0];

    // Valores leídos de registros
    logic [7:0] rx_val, ry_val;
    assign rx_val = rx_sel ? r1 : r0;
    assign ry_val = ry_sel ? r1 : r0;

    // Señales de control para memoria de datos
    logic [9:0] dm_addr;
    logic [7:0] dm_din;
    logic       dm_we;
    logic [7:0] dm_dout;

    // Direccionamiento de la BRAM de Datos
    always_comb begin
        if (state == ST_LOAD) begin
            dm_addr = load_byte_cnt[9:0];
            dm_din  = i_data[7:0];
            dm_we   = i_valid && load_byte_cnt[10];
        end else if (state == ST_EXEC && opcode == 5'b01001) begin // STRM
            dm_addr = addr_imm10;
            dm_din  = rx_val;
            dm_we   = 1'b1;
        end else if (state == ST_DUMP || state == ST_DUMP_PREP) begin
            dm_addr = dump_addr;
            dm_din  = 8'h00;
            dm_we   = 1'b0;
        end else begin
            dm_addr = addr_imm10;
            dm_din  = 8'h00;
            dm_we   = 1'b0;
        end
    end

    // Instancia / Inferencia síncrona de Data BRAM (evita driver múltiple)
    always_ff @(posedge i_clk) begin
        if (dm_we) begin
            data_mem[dm_addr] <= dm_din;
        end
        dm_dout <= data_mem[dm_addr];
    end

    // Proceso Principal (FSM y ALU)
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state         <= ST_LOAD;
            pc            <= '0;
            dump_addr     <= '0;
            load_byte_cnt <= '0;
            r0            <= '0;
            r1            <= '0;
            carry         <= 1'b0;
            o_valid       <= 1'b0;
            o_last        <= 1'b0;
            o_data        <= '0;
            low_byte      <= '0;
            instr         <= '0;
        end else begin
            case (state)
                ST_LOAD: begin
                    o_valid <= 1'b0;
                    o_last  <= 1'b0;
                    if (i_valid) begin
                        if (i_first) load_byte_cnt <= '0;

                        if (!load_byte_cnt[10]) begin
                            if (load_byte_cnt[0]) begin
                                prog_mem[load_byte_cnt[9:1]] <= {i_data[7:0], low_byte};
                            end else begin
                                low_byte <= i_data[7:0];
                            end
                        end

                        load_byte_cnt <= load_byte_cnt + 1'b1;

                        if (i_last) begin
                            state <= ST_FETCH;
                            pc    <= '0;
                        end
                    end
                end

                // Estado de Lectura de Instrucción (Respeta el ciclo de latencia de BRAM)
                ST_FETCH: begin
                    instr <= prog_mem[pc];
                    pc    <= pc + 1'b1;
                    state <= ST_EXEC;
                end

                ST_EXEC: begin
                    state <= ST_FETCH; // Por defecto pasa a la siguiente instrucción

                    case (opcode)
                        5'b00000: begin
                            if (instr[11] == 1'b1) begin // STOP
                                state     <= ST_DUMP_PREP;
                                dump_addr <= '0;
                            end
                        end

                        5'b00010: carry <= instr[11]; // CLRC / SETC

                        5'b00100: pc <= addr_imm10[8:0]; // JMP

                        5'b00101: if (!carry) pc <= addr_imm10[8:0]; // CJMPNC

                        5'b00110: if (carry) pc <= addr_imm10[8:0]; // CJMPC

                        5'b01000: begin // LDRM
                            if (rx_sel) r1 <= dm_dout;
                            else        r0 <= dm_dout;
                        end

                        5'b01001: ; // STRM (Manejado en bloque de memoria)

                        5'b01010: begin // LDRI
                            if (rx_sel) r1 <= imm8;
                            else        r0 <= imm8;
                        end

                        5'b01011: begin // ADDR
                            automatic logic [8:0] sum = rx_val + ry_val + carry;
                            carry <= sum[8];
                            if (rx_sel) r1 <= sum[7:0]; else r0 <= sum[7:0];
                        end

                        5'b01100: begin // SUBR
                            automatic logic [8:0] sub = rx_val - ry_val - carry;
                            carry <= sub[8];
                            if (rx_sel) r1 <= sub[7:0]; else r0 <= sub[7:0];
                        end

                        5'b01101: begin // ROL
                            carry <= rx_val[7];
                            if (rx_sel) r1 <= {rx_val[6:0], rx_val[7]};
                            else        r0 <= {rx_val[6:0], rx_val[7]};
                        end

                        5'b01110: begin // ROR
                            carry <= rx_val[0];
                            if (rx_sel) r1 <= {rx_val[0], rx_val[7:1]};
                            else        r0 <= {rx_val[0], rx_val[7:1]};
                        end

                        5'b01111: begin // SHR
                            carry <= rx_val[0];
                            if (rx_sel) r1 <= {1'b0, rx_val[7:1]};
                            else        r0 <= {1'b0, rx_val[7:1]};
                        end

                        5'b10000: begin // SHL
                            carry <= rx_val[7];
                            if (rx_sel) r1 <= {rx_val[6:0], 1'b0};
                            else        r0 <= {rx_val[6:0], 1 meb0}; // Solucionado a 1'b0
                        end

                        5'b10001: begin // ASHR
                            carry <= rx_val[0];
                            if (rx_sel) r1 <= {rx_val[7], rx_val[7:1]};
                            else        r0 <= {rx_val[7], rx_val[7:1]};
                        end

                        5'b10010: begin // NAND
                            if (rx_sel) r1 <= ~(rx_val & ry_val);
                            else        r0 <= ~(rx_val & ry_val);
                        end

                        5'b10011: begin // XOR
                            if (rx_sel) r1 <= rx_val ^ ry_val;
                            else        r0 <= rx_val ^ ry_val;
                        end

                        default: begin // Opcodes no definidos provocan STOP
                            state     <= ST_DUMP_PREP;
                            dump_addr <= '0;
                        end
                    endcase
                end

                // Prepara la dirección para compensar la latencia de 1 ciclo de la BRAM
                ST_DUMP_PREP: begin
                    dump_addr <= dump_addr + 1'b1;
                    state     <= ST_DUMP;
                end

                ST_DUMP: begin
                    o_valid   <= 1'b1;
                    o_data    <= dm_dout;
                    dump_addr <= dump_addr + 1'b1;

                    if (dump_addr == 1023) begin
                        o_last <= 1'b1;
                        state  <= ST_LOAD;
                    end
                end

                default: state <= ST_LOAD;
            endcase
        end
    end

endmodule