`timescale 1ns / 1ps

// =============================================================================
// task_10  --  Memory-Mapped Device Controller
// =============================================================================

// -----------------------------------------------------------------------------
// task10_regfile : generic N x WIDTH register file, sync write, comb read.
// -----------------------------------------------------------------------------
module task10_regfile #(
    parameter int N     = 4,
    parameter int WIDTH = 16
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 we,
    input  logic [$clog2(N)-1:0] waddr,
    input  logic [WIDTH-1:0]     wdata,
    input  logic [$clog2(N)-1:0] raddr,
    output logic [WIDTH-1:0]     rdata
);
  logic [WIDTH-1:0] mem [0:N-1];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < N; i++) begin
        mem[i] <= '0;
      end
    end else if (we) begin
      mem[waddr] <= wdata;
    end
  end

  // Lectura combinacional directa
  assign rdata = mem[raddr];
endmodule


// -----------------------------------------------------------------------------
// task10_shift_reg_in : serial-in / parallel-out shift register.
// -----------------------------------------------------------------------------
module task10_shift_reg_in #(
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             shift_en,
    input  logic             serial_bit,
    output logic [WIDTH-1:0] parallel_out,
    output logic             any_shift_done
);
  always_ff @(posedge clk) begin
    if (rst) begin
      parallel_out   <= '0;
      any_shift_done <= 1'b0;
    end else if (shift_en) begin
      parallel_out   <= {parallel_out[WIDTH-2:0], serial_bit};
      any_shift_done <= 1'b1;
    end
  end
endmodule


// -----------------------------------------------------------------------------
// task10_latch_reg : parallel-load / parallel-read latch (for serial-out).
// -----------------------------------------------------------------------------
module task10_latch_reg #(
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             we,
    input  logic [WIDTH-1:0] wdata,
    output logic [WIDTH-1:0] rdata
);
  always_ff @(posedge clk) begin
    if (rst) begin
      rdata <= '0;
    end else if (we) begin
      rdata <= wdata;
    end
  end
endmodule


// -----------------------------------------------------------------------------
// task10_timer : 16-bit free-running timer.
// -----------------------------------------------------------------------------
module task10_timer #(
    parameter int WIDTH = 16
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             load,
    input  logic             set_target,
    input  logic [WIDTH-1:0] count_in,
    input  logic [WIDTH-1:0] target_in,
    output logic [WIDTH-1:0] count_out,
    output logic [WIDTH-1:0] target_out,
    output logic             en,
    output logic             fire,
    output logic             match_latch
);
  always_ff @(posedge clk) begin
    if (rst) begin
      count_out   <= '0;
      target_out  <= {WIDTH{1'b1}};
      en          <= 1'b0;
      fire        <= 1'b0;
      match_latch <= 1 me;
    end else begin
      fire <= 1'b0; // Genera pulso de 1 ciclo

      if (set_target) begin
        target_out <= target_in;
      end

      if (load) begin
        count_out <= count_in;
        en        <= 1'b1;
      end else if (en) begin
        if (count_out == target_out) begin
          en          <= 1'b0;
          fire        <= 1'b1;
          match_latch <= 1'b1;
        end else begin
          count_out <= count_out + 1'b1;
        end
      end
    end
  end
endmodule


// =============================================================================
// task_10 : top wrapper
// =============================================================================
module task_10 #(
    parameter int TASK_INPUT_WIDTH  = 16,
    parameter int TASK_OUTPUT_WIDTH = 16
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

  // ---------- Opcodes ----------
  localparam logic [1:0] OP_NOP    = 2'b00;
  localparam logic [1:0] OP_WRITE  = 2'b01;
  localparam logic [1:0] OP_READ   = 2'b10;
  localparam logic [1:0] OP_OUTPUT = 2'b11;

  // ---------- Decodificación ----------
  wire [1:0] cmd_op   = i_data[15:14];
  wire [3:0] cmd_addr = i_data[9:6];

  // ---------- FSM ----------
  typedef enum logic [0:0] { S_CMD, S_WDATA } state_t;
  state_t     state, state_n;
  logic [3:0] pending_addr, pending_addr_n;

  // ---------- Señales de Control ----------
  logic rfa_we, rfb_we;
  logic serin_shift;
  logic serout_we;
  logic timer_load, timer_set_target;

  // ---------- Salidas Registradas (Latencia 1 Ciclo) ----------
  logic        o_valid_n, o_last_n;
  logic [15:0] o_data_n;

  // ---------- Conexiones de Submódulos ----------
  logic [15:0] rfa_rdata, rfb_rdata;
  logic [15:0] serin_par;
  logic        serin_done;
  logic [15:0] serout_par;
  logic [15:0] tmr_count, tmr_target;
  logic        tmr_en, tmr_fire, tmr_match;

  // ---------- Capture de Dirección Oculta por Timer ----------
  logic [15:0] hidden_addr;
  logic        secret_rdy;

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      hidden_addr <= 16'h0;
      secret_rdy  <= 1'b0;
    end else if (tmr_fire) begin
      hidden_addr <= serin_par;
      secret_rdy  <= 1'b1;
    end
  end

  // ---------- Sub-módulos ----------
  task10_regfile #(.N(4), .WIDTH(16)) u_rf_a (
      .clk   (i_clk),
      .rst   (i_rst),
      .we    (rfa_we),
      .waddr (pending_addr[1:0]),
      .wdata (i_data),
      .raddr (cmd_addr[1:0]),
      .rdata (rfa_rdata)
  );

  task10_regfile #(.N(4), .WIDTH(16)) u_rf_b (
      .clk   (i_clk),
      .rst   (i_rst),
      .we    (rfb_we),
      .waddr (pending_addr[1:0]),
      .wdata (i_data),
      .raddr (cmd_addr[1:0]),
      .rdata (rfb_rdata)
  );

  task10_shift_reg_in #(.WIDTH(16)) u_serin (
      .clk            (i_clk),
      .rst            (i_rst),
      .shift_en       (serin_shift),
      .serial_bit     (i_data[0]),
      .parallel_out   (serin_par),
      .any_shift_done (serin_done)
  );

  task10_latch_reg #(.WIDTH(16)) u_serout (
      .clk   (i_clk),
      .rst   (i_rst),
      .we    (serout_we),
      .wdata (i_data),
      .rdata (serout_par)
  );

  task10_timer #(.WIDTH(16)) u_timer (
      .clk         (i_clk),
      .rst         (i_rst),
      .load        (timer_load),
      .set_target  (timer_set_target),
      .count_in    (i_data),
      .target_in   (i_data),
      .count_out   (tmr_count),
      .target_out  (tmr_target),
      .en          (tmr_en),
      .fire        (tmr_fire),
      .match_latch (tmr_match)
  );

  // ---------- Multiplexor Lectura de Bus ----------
  function automatic logic [15:0] bus_read(input logic [3:0] a);
    logic [15:0] v;
    case (a)
      4'h0, 4'h1, 4'h2, 4'h3: v = rfa_rdata;
      4'h4, 4'h5, 4'h6, 4'h7: v = rfb_rdata;
      4'h8:                   v = serin_par;
      4'h9:                   v = serout_par;
      4'hA:                   v = tmr_count;
      4'hB:                   v = tmr_target;
      4'hC:                   v = {8'h0, hidden_addr[3:0], serin_done, secret_rdy, tmr_match, tmr_en};
      default:                v = 16'h0;
    endcase
    return v;
  endfunction

  // ---------- FSM Mealy Combinacional ----------
  always_comb begin
    state_n          = state;
    pending_addr_n   = pending_addr;
    rfa_we           = 1'b0;
    rfb_we           = 1'b0;
    serin_shift      = 1'b0;
    serout_we        = 1'b0;
    timer_load       = 1'b0;
    timer_set_target = 1'b0;

    o_valid_n        = 1'b0;
    o_last_n         = 1'b0;
    o_data_n         = o_data;

    case (state)
      S_CMD: begin
        if (i_valid) begin
          case (cmd_op)
            OP_WRITE: begin
              pending_addr_n = cmd_addr;
              state_n        = S_WDATA;
            end
            OP_READ: begin
              // Operación interna de registro (sin emisión de paquete)
            end
            OP_OUTPUT: begin
              o_valid_n = 1'b1;
              o_last_n  = i_last;
              o_data_n  = bus_read(cmd_addr);
            end
            default: ;
          endcase
        end
      end

      S_WDATA: begin
        if (i_valid) begin
          case (pending_addr)
            4'h0, 4'h1, 4'h2, 4'h3: rfa_we           = 1'b1;
            4'h4, 4'h5, 4'h6, 4'h7: rfb_we           = 1'b1;
            4'h8:                   serin_shift      = 1'b1;
            4'h9:                   serout_we        = 1'b1;
            4'hA:                   timer_load       = 1'b1;
            4'hB:                   timer_set_target = 1'b1;
            default: ;
          endcase
          state_n = S_CMD;
        end
      end
    endcase
  end

  // ---------- Registros de Estado y Salida (Alineación a 1 Ciclo) ----------
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state        <= S_CMD;
      pending_addr <= 4'h0;
      o_valid      <= 1'b0;
      o_last       <= 1'b0;
      o_data       <= 16'h0;
    end else begin
      state        <= state_n;
      pending_addr <= pending_addr_n;
      o_valid      <= o_valid_n;
      o_last       <= o_last_n;
      o_data       <= o_data_n;
    end
  end

endmodule