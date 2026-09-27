`timescale 1ns/1ps

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

   // The externally visible port map above is deliberately kept unchanged.
   // FRAME_START_MSB_FIRST is sent left-to-right on the serial line.
   localparam logic [7:0] FRAME_START = FRAME_START_MSB_FIRST[7:0];

   // Two 136-bit banks hold completed output frames.  One bank is filled
   // from in_clk while the other one is serialized from clk64.
   logic [135:0] frame_mem [0:1];
   logic         write_toggle;

   logic [7:0]   header_shift;
   logic [127:0] rx_frame;
   logic [7:0]   detected_index;
   logic [6:0]   payload_index;
   logic         collecting;

   // Detect the frame start even if reset is released in the middle of a
   // frame, then collect the following 120 one-hot payload bits.
   always_ff @(posedge in_clk or negedge rst_n) begin
      if (!rst_n) begin
         header_shift   <= 8'd0;
         rx_frame       <= 128'd0;
         detected_index <= 8'd0;
         payload_index  <= 7'd0;
         collecting     <= 1'b0;
         write_toggle   <= 1'b0;
      end else if (!collecting) begin
         header_shift <= {header_shift[6:0], in_data};
         if ({header_shift[6:0], in_data} == FRAME_START) begin
            // Subsequent payload shifts move the start word to [127:120].
            rx_frame       <= {{120{1'b0}}, FRAME_START};
            detected_index <= 8'd0;
            payload_index  <= 7'd0;
            collecting     <= 1'b1;
         end
      end else begin
         rx_frame <= {rx_frame[126:0], in_data};
         if (in_data)
            detected_index <= {1'b0, payload_index};

         if (payload_index == 7'd119) begin
            // Append the current (last) payload bit and the inverted index.
            frame_mem[write_toggle] <= {
               {rx_frame[126:0], in_data},
               ~(in_data ? {1'b0, payload_index} : detected_index)
            };
            write_toggle <= ~write_toggle;
            collecting   <= 1'b0;
         end else begin
            payload_index <= payload_index + 1'b1;
         end
      end
   end

   // A 7-bit fractional-N accumulator generates exactly 8.5 MHz on average:
   // 64 MHz * 17 / 128.  Its high and low phases are 3 or 4 clk64 cycles,
   // satisfying the requested output duty-cycle tolerance.
   logic [6:0] nco_phase;
   wire  [6:0] nco_next        = nco_phase + 7'd17;
   wire        out_clk_falling = nco_phase[6] && !nco_next[6];

   logic wr_sync_1, wr_sync_2;
   logic tx_active;
   logic tx_seen;
   logic tx_bank;
   logic [7:0] tx_bit_index;

   assign out_clk = nco_phase[6];

   // Keep serialization in the clk64 domain.  out_data is modified only
   // while out_clk falls, so it remains stable through its rising edge.
   always_ff @(posedge clk64 or negedge rst_n) begin
      if (!rst_n) begin
         nco_phase    <= 7'd0;
         wr_sync_1    <= 1'b0;
         wr_sync_2    <= 1'b0;
         tx_active    <= 1'b0;
         tx_seen      <= 1'b0;
         tx_bank      <= 1'b0;
         tx_bit_index <= 8'd0;
         out_data     <= 1'b0;
      end else begin
         nco_phase <= nco_next;
         wr_sync_1 <= write_toggle;
         wr_sync_2 <= wr_sync_1;

         if (out_clk_falling) begin
            if (!tx_active) begin
               if (wr_sync_2 != tx_seen) begin
                  // write_toggle identifies the *next* write bank; select
                  // the opposite bank, which contains the completed frame.
                  tx_active    <= 1'b1;
                  tx_seen      <= wr_sync_2;
                  tx_bank      <= ~wr_sync_2;
                  tx_bit_index <= 8'd1;
                  out_data     <= frame_mem[~wr_sync_2][135];
               end else begin
                  out_data <= 1'b0;
               end
            end else begin
               out_data <= frame_mem[tx_bank][135 - tx_bit_index];
               if (tx_bit_index == 8'd135)
                  tx_active <= 1'b0;
               else
                  tx_bit_index <= tx_bit_index + 1'b1;
            end
         end
      end
   end

endmodule
