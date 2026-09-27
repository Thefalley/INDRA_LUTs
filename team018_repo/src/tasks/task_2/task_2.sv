`timescale 1ns / 1ps

module task_2
#(
  parameter int TASK_INPUT_WIDTH  = 16,
  parameter int TASK_OUTPUT_WIDTH = 32
)(
  input wire                          i_clk,
  input wire                          i_rst,
  input wire                          i_valid,
  input wire                          i_first,
  input wire                          i_last,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data0,
  input wire  [TASK_INPUT_WIDTH-1:0]  i_data1,
  output logic                         o_valid,
  output logic                         o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

    localparam logic [31:0] HEADER_Q1_15 = 32'h01007171;
    // i_data0: measured signal; i_data1: temperature. Extend before shifts.
    wire signed [31:0] measured = $signed(i_data0);
    wire signed [31:0] temperature = $signed(i_data1);
    logic signed [31:0] measured_x23, temperature_x80;
    logic signed [31:0] correction;
    logic valid_product, last_product, valid_correction, last_correction;
    logic capturing, busy;
    wire start_packet = !busy && i_valid && i_first;
    wire accept_sample = i_valid && (capturing || start_packet);

    // One packet at a time, as in the original implementation. The producer
    // must wait for o_last before starting another packet (there is no ready).
    // The header precedes the first arithmetic result. Input gaps propagate;
    // no frame-size buffer is required for this per-sample correction.
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            capturing <= 1'b0;
            busy <= 1'b0;
            valid_product <= 1'b0;
            last_product <= 1'b0;
            valid_correction <= 1'b0;
            last_correction <= 1'b0;
            o_valid <= 1'b0;
            o_last <= 1'b0;
            o_data <= '0;
        end else begin
            valid_product <= accept_sample;
            last_product <= accept_sample && i_last;
            valid_correction <= valid_product;
            last_correction <= valid_product && last_product;

            if (start_packet) busy <= 1'b1;
            if (accept_sample) begin
                capturing <= !i_last;
                // Constant products implemented with adders, without DSPs.
                measured_x23 <= (measured <<< 4) + (measured <<< 3) - measured;
                temperature_x80 <= (temperature <<< 6) + (temperature <<< 4);
            end
            if (valid_product)
                correction <= -32'sd1599 - temperature_x80 + (measured_x23 >>> 5);

            o_valid <= start_packet || valid_correction;
            o_last <= valid_correction && last_correction;
            if (start_packet) begin
                o_data <= HEADER_Q1_15;
            end else if (valid_correction) begin
                if (correction > 32'sd32767)
                    o_data <= 32'h00007fff;
                else if (correction < -32'sd32768)
                    o_data <= 32'hffff8000;
                else
                    o_data <= {{16{correction[15]}}, correction[15:0]};
                if (last_correction) busy <= 1'b0;
            end else begin
                o_data <= '0;
            end
        end
    end

endmodule
