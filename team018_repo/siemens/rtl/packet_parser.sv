// =============================================================================
// Module      : packet_parser
// Description : Parses the incoming AXI-Stream packet.
//               - Extracts header fields (N, T, S)
//               - Writes coefficients into BRAM
//               - Forwards sample words to the FIR channel engines
//               s_ready is ALWAYS HIGH (no backpressure to input).
//
// *** HACKATHON EXERCISE ***
// Implement the two always_ff blocks marked with TODO below.
// Refer to the Packet_parser_requirements.docx in doc/ for full specifications.
// =============================================================================
module packet_parser #(
    parameter int MAX_CHANNELS = 4,
    parameter int MAX_TAPS     = 16,
    parameter int MAX_SAMPLES  = 64
)(
    input  logic        clk,
    input  logic        rst_n,

    // Input AXI-Stream
    input  logic [31:0] s_data,
    input  logic        s_valid,
    output logic        s_ready,    // Always HIGH

    // Parsed header outputs (registered, valid when hdr_valid=1)
    output logic [3:0]  num_channels,   // N
    output logic [4:0]  num_taps,       // T
    output logic [6:0]  num_samples,    // S
    output logic        hdr_valid,      // Pulses high for 1 cycle when header parsed

    // Coefficient BRAM write port
    output logic        coeff_we,
    output logic [5:0]  coeff_addr,     // log2(64)=6 bits
    output logic [15:0] coeff_din,

    // Sample output to FIR engines
    output logic [15:0] sample_data,
    output logic [1:0]  sample_ch,      // Which channel this sample belongs to
    output logic        sample_valid,
    output logic        sample_last,    // Last sample of entire packet

    // Packet done indicator
    output logic        pkt_done
);

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        st_header   = 2'd0,
        ST_COEFFS   = 2'd1,
        ST_SAMPLES  = 2'd2,
        ST_IDLE     = 2'd3
    } state_t;

    state_t state, state_next;

    // Registered header fields
    logic [3:0] r_num_ch;
    logic [4:0] r_num_taps;
    logic [6:0] r_num_samp;

    // Counters
    logic [7:0] coeff_cnt;   // counts received coefficient words
    logic [7:0] sample_cnt;  // counts received sample words
    logic [7:0] total_coeffs; // N x T
    logic [8:0] total_samples; // N x S , max = 4 x 64 = 256

    // Per-channel coefficient addressing (avoids sequential-vs-strided mismatch)
    // The FIR channels read channel c's tap k from address: c*MAX_TAPS + k.
    // These counters track which channel/tap we are currently writing so we can
    // form the identical address here on the write side.
    logic [1:0] coeff_ch_idx;  // current channel being written (0..3)
    logic [4:0] coeff_tap_idx; // current tap within that channel (0..MAX_TAPS-1)

    // s_ready is always asserted
    assign s_ready = 1'b1;

    // =========================================================================
    // TODO 1: Main sequential logic — FSM state transitions + header/counter logic
    // =========================================================================
    //
    // Implement an always_ff block (posedge clk or negedge rst_n) that:
    //
    //   RESET (rst_n == 0):
    //     - Set state to st_header
    //     - Clear all registered header fields (r_num_ch, r_num_taps, r_num_samp)
    //     - Clear all counters (coeff_cnt, sample_cnt, total_coeffs, total_samples)
    //     - Clear coefficient addressing (coeff_ch_idx, coeff_tap_idx)
    //     - Deassert hdr_valid and pkt_done
    //
    //   NORMAL OPERATION:
    //     - Default hdr_valid and pkt_done to 0 each cycle (pulse behavior)
    //     - Implement a case statement on 'state' with three states:
    //
    //       st_header:
    //         When s_valid, extract header fields from s_data:
    //           s_data[31:24] → r_num_ch    (number of channels, N)
    //           s_data[23:16] → r_num_taps  (number of taps, T)
    //           s_data[15:0]  → r_num_samp  (number of samples, S)
    //         Compute total_coeffs = N * T, total_samples = N * S
    //         Clear coeff_cnt, sample_cnt, coeff_ch_idx, coeff_tap_idx
    //         Pulse hdr_valid for one cycle
    //         Transition to ST_COEFFS
    //
    //       ST_COEFFS:
    //         When s_valid, increment coeff_cnt
    //         Track per-channel tap index for BRAM addressing:
    //           If coeff_tap_idx == r_num_taps - 1: reset tap index, advance channel
    //           Else: increment coeff_tap_idx
    //         When coeff_cnt reaches total_coeffs - 1: transition to ST_SAMPLES
    //
    //       ST_SAMPLES:
    //         When s_valid, increment sample_cnt
    //         When sample_cnt reaches total_samples - 1:
    //           Pulse pkt_done for one cycle
    //           Transition back to st_header
    //
    //       default: go to st_header
    //
    // =========================================================================


    // -------------------------------------------------------------------------
    // Output registered header fields
    // -------------------------------------------------------------------------
    assign num_channels = r_num_ch;
    assign num_taps     = r_num_taps;
    assign num_samples  = r_num_samp;

    // -------------------------------------------------------------------------
    // Coefficient BRAM write logic
    // Address = coeff_ch_idx * MAX_TAPS + coeff_tap_idx so that channel c's
    // tap k lands at address (c * MAX_TAPS + k), exactly where each
    // fir_channel instance will later read it (CH_ID * MAX_TAPS + tap).
    // MAX_TAPS = 16 = 2^4, so the address is simply {coeff_ch_idx, coeff_tap_idx[3:0]}.
    // -------------------------------------------------------------------------
    always_comb begin
        coeff_we   = 1'b0;
        coeff_addr = {coeff_ch_idx, coeff_tap_idx[3:0]};
        coeff_din  = s_data[15:0];

        if (state == ST_COEFFS && s_valid)
            coeff_we = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Sample forwarding logic
    // Channel index = sample_cnt / num_samples (integer division)
    // We track channel index with a separate counter for efficiency
    // -------------------------------------------------------------------------
    logic [1:0] ch_idx;
    logic [6:0] samp_in_ch; // sample index within current channel

    // =========================================================================
    // TODO 2: Sample channel tracking — per-channel sample counter
    // =========================================================================
    //
    // Implement an always_ff block (posedge clk or negedge rst_n) that:
    //
    //   RESET (rst_n == 0):
    //     - Clear ch_idx and samp_in_ch to 0
    //
    //   NORMAL OPERATION:
    //     - When in st_header state AND s_valid:
    //         Reset ch_idx and samp_in_ch to 0 (new packet starting)
    //     - When in ST_SAMPLES state AND s_valid:
    //         If samp_in_ch reaches r_num_samp - 1:
    //           Reset samp_in_ch to 0 and advance ch_idx (next channel)
    //         Else:
    //           Increment samp_in_ch
    //
    // =========================================================================


    assign sample_data  = s_data[15:0];
    assign sample_ch    = ch_idx;
    assign sample_valid = (state == ST_SAMPLES) && s_valid;
    assign sample_last  = sample_valid && (samp_in_ch == r_num_samp - 1);

endmodule
