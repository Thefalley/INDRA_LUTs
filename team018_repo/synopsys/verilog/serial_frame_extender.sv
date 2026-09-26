// File: serial_frame_extender.sv
// Purpose: receive a continuous 8 Mbit/s serial input stream,
//          identifies the bit position of a single '1' bit within each frame,
//          and outputs an extended frame containing the original 128 bit data followed
//          by an 8 bit binary representation of the detected bit position.
// Notes  : Input sampling occurs on rising edge of in_clk; output data
//          changes on falling edge of out_clk and is sampled on out_clk rising.
//          Max latency from input to output should be < 2 frames.

module serial_frame_extender #(
  parameter int unsigned FRAME_START_MSB_FIRST = 8'h4E,  // 0100_1110
  parameter int unsigned START_LSBF            = 8'h72   // 0111_0010 (0x4E LSB-first)
) (
  input  logic clk64,      // 64 MHz system clock (synchronous to in_clk)
  input  logic rst_n,
  // Input serial interface
  input  logic in_clk,     // ~8 MHz, free-running, 50% +/-10%
  input  logic in_data,    // sampled on rising edge of in_clk
  // Output serial interface
  output logic out_clk,    // derived clock, free-running
  output logic out_data    // changes on falling edge of out_clk; sample on rising
);
   // replace with your own implementation
   assign out_data = in_data;
   assign out_clk = in_clk;
   

endmodule
