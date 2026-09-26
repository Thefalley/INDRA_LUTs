`timescale 1ns / 1ps
module task_16
#(
  parameter int TASK_INPUT_WIDTH  = 32,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input wire                              i_clk,
  input wire                              i_rst,

  input wire                              i_valid,
  output logic                            i_ready,
  input wire                              i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]      i_data,
  input wire  [TASK_INPUT_WIDTH/8-1:0]    i_keep,

  input wire                              o_ready,
  output logic                            o_valid,
  output logic                            o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0]    o_data,
  output logic [TASK_OUTPUT_WIDTH/8-1:0]  o_keep
);

  // Internal signals
    logic [2:0] in_bytes;
    logic [3:0] byte_cnt;
    logic       in_fire;
    logic       out_fire;
    logic       pkt_ending;

  // Inst 1: Byte Decoder
  byte_decoder #(
      .BYTE_DECODER_WIDTH(TASK_INPUT_WIDTH/8)
  ) u_byte_decoder (
      .i_keep  (i_keep),
      .o_bytes (in_bytes)
  );

  // Inst 2: Handshake Control
  handshake_control u_handshake_control (
      .i_clk        (i_clk),
      .i_rst        (i_rst),
      .i_valid      (i_valid),
      .i_ready      (i_ready),
      .i_last       (i_last),
      .o_valid      (o_valid),
      .o_ready      (o_ready),
      .o_last       (o_last),
      .i_byte_cnt   (byte_cnt),
      .o_in_fire    (in_fire),
      .o_out_fire   (out_fire),
      .o_pkt_ending (pkt_ending)
  );

  // Inst 3: Accumulator
  accumulate_pkg #(
      .DATA_WIDTH(TASK_OUTPUT_WIDTH)
  ) u_accumulate_pkg (
      .i_clk      (i_clk),
      .i_rst      (i_rst),
      .i_in_fire  (in_fire),
      .i_out_fire (out_fire),
      .i_last_out (o_last),
      .i_in_bytes (in_bytes),
      .i_data     (i_data),
      .o_data     (o_data),
      .o_keep     (o_keep),
      .o_byte_cnt (byte_cnt)
  );

endmodule
