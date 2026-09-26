`timescale 1ns / 1ps
module task_13
#(
  parameter int TASK_INPUT_WIDTH  = 16,
  parameter int TASK_OUTPUT_WIDTH = 16
)(
  input wire                          i_clk,
  input wire                          i_rst,

  input wire                          i_valid,
  input wire                          i_first,
  input wire                          i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data,

  output logic                         o_valid,
  output logic                         o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    // Internal signals
    logic [15:0] n_periods;
    logic [15:0] wave_shape;
    logic [10:0] phase;
    logic        gen_active;
    logic [11:0] sample_cnt;

    // Inst 1: Control and FSM
    nco_control u_nco_control (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_valid      (i_valid),
        .i_first      (i_first),
        .i_last       (i_last),
        .i_data       (i_data),
        .o_valid      (o_valid),
        .o_last       (o_last),
        .o_n_periods  (n_periods),
        .o_wave_shape (wave_shape),
        .o_gen_active (gen_active),
        .o_sample_cnt (sample_cnt)
    );

    // Inst 2: Phase accumulator
    phase_accumulator u_phase_accumulator (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_gen_active (gen_active),
        .i_n_periods  (n_periods[10:0]),
        .o_phase      (phase)
    );

    // Inst 3: Wave Generator
    wave_generator #(
        .DATA_WIDTH(TASK_OUTPUT_WIDTH)
    ) u_wave_generator (
        .i_phase      (phase),
        .i_n_periods  (n_periods[10:0]),
        .i_wave_shape (wave_shape[1:0]),
        .o_data       (o_data)
    );

endmodule