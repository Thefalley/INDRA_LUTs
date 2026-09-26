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
   logic in_clk_d;
   logic [7:0] in_count;
   logic [6:0] payload_position;
   logic [127:0] input_frame;
   logic [135:0] output_frame;
   logic [7:0] out_count;
   logic output_busy;
   logic [7:0] out_phase;
   logic out_clk_r;

   assign out_clk = out_clk_r;

   always_ff @(posedge clk64 or negedge rst_n) begin
      if (!rst_n) begin
         in_clk_d <= 1'b0;
         in_count <= '0;
         payload_position <= '0;
         input_frame <= '0;
      end else begin
         in_clk_d <= in_clk;
         if (in_clk && !in_clk_d) begin
            input_frame <= {input_frame[126:0], in_data};
            if (in_count >= 8 && in_data)
              payload_position <= in_count - 8;
            if (in_count == 8'd127) begin
               in_count <= '0;
            end else begin
               in_count <= in_count + 1'b1;
            end
         end
      end
   end

   always_ff @(posedge clk64 or negedge rst_n) begin
      if (!rst_n) begin
         out_phase <= '0;
         out_clk_r <= 1'b0;
         output_frame <= '0;
         out_count <= '0;
         output_busy <= 1'b0;
         out_data <= 1'b0;
      end else begin
         if ({1'b0, out_phase} + 9'd68 >= 9'd256) begin
            out_phase <= out_phase + 8'd68;
            out_clk_r <= ~out_clk_r;
            if (out_clk_r) begin
               if (output_busy) begin
                  out_data <= output_frame[135 - out_count];
                  if (out_count == 8'd135) begin
                     out_count <= '0;
                     output_busy <= 1'b0;
                  end else begin
                     out_count <= out_count + 1'b1;
                  end
               end
            end
         end else begin
            out_phase <= out_phase + 8'd68;
         end

         if (in_clk && !in_clk_d && in_count == 8'd127 && !output_busy) begin
            output_frame <= {{input_frame[126:0], in_data}, ~(in_data ? 7'd119 : payload_position)};
            output_busy <= 1'b1;
            out_count <= '0;
         end
      end
   end

endmodule
