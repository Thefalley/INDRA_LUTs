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

    // Memorias inferidas en Block RAM (BRAM)
    (* ram_style = "block" *) logic [15:0] prog_mem [0:512]; // 512 palabras x 16 bits
    (* ram_style = "block" *) logic [7:0]  data_mem [0:1023]; // 1024 bytes x 8 bits

    typedef enum logic [1:0] {
        ST_LOAD,
        ST_EXEC,
        ST_DUMP
    } state_t;

    state_t state;

    // Registros del procesador y contadores
    logic [8:0]  pc;
    logic [9:0]  dump_addr;
    logic [10:0] load_byte_cnt;
    logic [7:0]  r0, r1;
    logic        carry;
    logic [15:0] instr;

    // Byte temporal para ensamblar la instrucción de 16 bits
    logic [7:0]  low_byte;

    // Decodificación de la instrucción actual
    logic [4:0]  opcode;
    logic        rx_sel, ry_sel;
    logic [9:0]  addr_imm10;
    logic [7:0]  imm8;

    assign opcode     = instr[15:11];
    assign rx_sel     = instr[10];
    assign ry_sel     = instr[9];
    assign addr_imm10 = instr[9:0];
    assign imm8       = instr[7:0];

    // Selección de registros
    logic [7:0] rx_val, ry_val;
    assign rx_val = rx_sel ? r1 : r0;
    assign ry_val = ry_sel ? r1 : r0;

    // Inferencia de lecturas de memoria
    logic [7:0] dm_read_val;
    always_ff @(posedge i_clk) begin
        if (state == ST_LOAD && i_valid && !load_byte_cnt[10]) begin
            data_mem[load_byte_cnt[9:0]] <= i_data[7:0];
        end else if (state == ST_EXEC && opcode == 5'b01001) begin // STRM
            data_mem[addr_imm10] <= rx_val;
        end
        
        if (state == ST_EXEC) begin
            dm_read_val <= data_mem[addr_imm10];
        end else if (state == ST_DUMP) begin
            o_data <= data_mem[dump_addr];
        end
    end

    // Proceso principal FSM y Ejecución de Instrucciones
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            state         <= ST_LOAD;
            pc            <= '0;
            dump_addr     <= '0;
            load_byte_cnt <= '0;
            r0            <= '0;
            r1            <= '0;
            carry         <= 1'b0;
            o_valid       <= 1 meb0;
            o_last        <= 1'b0;
        end else begin
            case (state)
                ST_LOAD: begin
                    if (i_valid) begin
                        if (i_first) load_byte_cnt <= '0;
                        
                        // Guardar datos en PM (primeros 1024 bytes) o DM (siguientes 1024 bytes)
                        if (!load_byte_cnt[10]) begin
                            if (load_byte_cnt[0]) begin
                                prog_mem[load_byte_cnt[9:1]] <= {i_data[7:0], low_byte};
                            end else begin
                                low_byte <= i_data[7:0];
                            end
                        end

                        load_byte_cnt <= load_byte_cnt + 1'b1;

                        if (i_last) begin
                            state <= ST_EXEC;
                            pc    <= '0;
                        end
                    end
                end

                ST_EXEC: begin
                    instr <= prog_mem[pc];
                    pc    <= pc + 1'b1;

                    case (opcode)
                        5'b00000: begin
                            if (instr[11] == 1'b1) begin // STOP / Opcode Ilegal
                                state <= ST_DUMP;
                                dump_addr <= '0;
                            end
                            // NOP
                        end

                        5'b00010: begin // CLRC / SETC
                            carry <= instr[11];
                        end

                        5'b00100: pc <= addr_imm10[8:0]; // JMP

                        5'b00101: if (!carry) pc <= addr_imm10[8:0]; // CJMPNC

                        5'b00110: if (carry) pc <= addr_imm10[8:0]; // CJMPC

                        5'b01000: begin // LDRM
                            if (rx_sel) r1 <= dm_read_val;
                            else        r0 <= dm_read_val;
                        end

                        5'b01001: ; // STRM se maneja en el bloque de memoria

                        5'b01010: begin // LDRI
                            if (rx_sel) r1 <= imm8;
                            else        r0 <= imm8;
                        end

                        5'b01011: begin // ADDR
                            {carry, rx_val} = rx_val + ry_val + carry;
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b01100: begin // SUBR
                            {carry, rx_val} = rx_val - ry_val - carry;
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b01101: begin // ROL
                            {carry, rx_val} = {rx_val[7], (rx_val << 1) | rx_val[7]};
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b01110: begin // ROR
                            {rx_val, carry} = {(rx_val[0] << 7) | (rx_val >> 1), rx_val[0]};
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b01111: begin // SHR
                            {rx_val, carry} = {1'b0, rx_val[7:1], rx_val[0]};
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b10000: begin // SHL
                            {carry, rx_val} = {rx_val[7], rx_val[6:0], 1'b0};
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b10001: begin // ASHR
                            {rx_val, carry} = {rx_val[7], rx_val[7:1], rx_val[0]};
                            if (rx_sel) r1 <= rx_val; else r0 <= rx_val;
                        end

                        5'b10010: begin // NAND
                            if (rx_sel) r1 <= ~(rx_val & ry_val);
                            else        r0 <= ~(rx_val & ry_val);
                        end

                        5'b10011: begin // XOR
                            if (rx_sel) r1 <= rx_val ^ ry_val;
                            else        r0 <= rx_val ^ ry_val;
                        end

                        default: begin // Cualquier otro opcode actúa como STOP
                            state <= ST_DUMP;
                            dump_addr <= '0;
                        end
                    endcase
                end

                ST_DUMP: begin
                    o_valid <= 1'b1;
                    dump_addr <= dump_addr + 1'b1;
                    
                    if (dump_addr == 1023) begin
                        o_last <= 1'b1;
                        state  <= ST_LOAD;
                    end
                end
            endcase
        end
    end

endmodule