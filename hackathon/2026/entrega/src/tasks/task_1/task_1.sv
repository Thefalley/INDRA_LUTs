`timescale 1ns / 1ps
module task_1
#(
  parameter int TASK_INPUT_WIDTH  = 8,
  parameter int TASK_OUTPUT_WIDTH = 8
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

  localparam int MAX_DATA_BYTES = 4096;
  localparam int FIRST_BUFFER_BYTES = 2048;

  typedef enum logic [3:0] {
    ST_WAIT,
    ST_CTRL_0,
    ST_STREAM,
    ST_LEFT_FLUSH,
    ST_SHORT_SHIFT_OUT,
    ST_SHORT_ROT_PREP,
    ST_SHORT_ROT_OUT,
    ST_ROT_RIGHT_PREP,
    ST_ROT_RIGHT_PRIME,
    ST_ROT_RIGHT_OUT,
    ST_LEFT_FLUSH_FETCH,
    ST_SHORT_SHIFT_FETCH,
    ST_SHORT_ROT_FETCH
  } state_t;

  state_t state, next_state;

  logic [7:0] control_1;
  logic [7:0] control_0;
  (* ram_style = "block" *) logic [7:0] first_mem_a [0:FIRST_BUFFER_BYTES-1];
  (* ram_style = "block" *) logic [7:0] first_mem_b [0:FIRST_BUFFER_BYTES-1];
  logic [10:0] first_addr_a, first_addr_b;
  logic [7:0] first_data_a, first_data_b;
  (* ram_style = "distributed" *) logic [7:0] right_mem_a [0:FIRST_BUFFER_BYTES-1];
  (* ram_style = "distributed" *) logic [7:0] right_mem_b [0:FIRST_BUFFER_BYTES-1];
  (* ram_style = "block" *) logic [7:0] rot_mem_a [0:MAX_DATA_BYTES-1];
  (* ram_style = "block" *) logic [7:0] rot_mem_b [0:MAX_DATA_BYTES-1];
  logic [11:0] read_index;
  logic [11:0] output_index;
  logic [11:0] flush_index;
  logic [12:0] data_count;
  logic [7:0] last_data;
  logic [11:0] rot_a;
  logic [11:0] rot_b;
  logic [11:0] rot_read_addr_a;
  logic [11:0] rot_read_addr_b;
  logic [2:0] rot_bits;
  logic [15:0] remaining_shift;
  logic [7:0] rot_data_a;
  logic [7:0] rot_data_b;

  // Text specification in 01_Shifter.pdf: bit 7 rotate, bit 6 right,
  // bits 5:0 plus ctrl0 form the 14-bit shift. The PDF's 0x9003 example
  // rotates 4099 bits, equivalent to 3 bits for its 32-bit payload.
  wire [13:0] shift_value = {control_1[5:0], control_0};
  wire [10:0] shift_bytes = shift_value[13:3];
  wire shift_partial = |shift_value[2:0];
  wire [11:0] lookahead_bytes = {1'b0, shift_bytes} + shift_partial;
  wire is_shift = !control_1[7];
  wire is_rotate = control_1[7];
  wire is_left = !control_1[6];
  wire is_right = control_1[6];

  function automatic logic [7:0] get_left_stream_byte(input logic [7:0] current_data);
    begin
      if (shift_partial)
        get_left_stream_byte = (last_data << shift_value[2:0]) |
                               (current_data >> (8 - shift_value[2:0]));
      else
        get_left_stream_byte = current_data;
    end
  endfunction

  function automatic logic [7:0] get_right_stream_byte(input logic [11:0] current_index,
                                                        input logic [7:0] current_data);
    logic [7:0] value;
    begin
      value = '0;
      if (current_index >= shift_bytes) begin
        if (!shift_partial) begin
          if (shift_bytes == 0)
            value = current_data;
          else
            value = right_mem_a[current_index[10:0] - shift_bytes];
        end else if (current_index == shift_bytes) begin
          if (shift_bytes == 0)
            value = current_data >> shift_value[2:0];
          else
            value = right_mem_a[current_index[10:0] - shift_bytes] >> shift_value[2:0];
        end else if (shift_bytes == 0) begin
          value = (right_mem_a[current_index[10:0] - 1'b1] << (8 - shift_value[2:0])) |
                  (current_data >> shift_value[2:0]);
        end else begin
          value = (right_mem_a[current_index[10:0] - shift_bytes - 1'b1] << (8 - shift_value[2:0])) |
                  (right_mem_b[current_index[10:0] - shift_bytes] >> shift_value[2:0]);
        end
      end
      get_right_stream_byte = value;
    end
  endfunction

  function automatic logic [7:0] get_short_shift_byte(input logic [11:0] byte_index);
    logic [11:0] source_index;
    begin
      source_index = byte_index + shift_bytes;
      if (source_index >= data_count)
        get_short_shift_byte = '0;
      else if (!shift_partial)
        get_short_shift_byte = first_data_a;
      else if (source_index == data_count - 1'b1)
        get_short_shift_byte = first_data_a << shift_value[2:0];
      else
        get_short_shift_byte = (first_data_a << shift_value[2:0]) |
                               (first_data_b >> (8 - shift_value[2:0]));
    end
  endfunction

  function automatic logic [7:0] get_short_rotate_left_byte;
    begin
      if (rot_bits == 0)
        get_short_rotate_left_byte = first_data_a;
      else
        get_short_rotate_left_byte = (first_data_a << rot_bits) |
                                     (first_data_b >> (8 - rot_bits));
    end
  endfunction

  function automatic logic [7:0] get_rotate_right_byte;
    begin
      if (rot_bits == 0)
        get_rotate_right_byte = rot_data_a;
      else
        get_rotate_right_byte = (rot_data_b << (8 - rot_bits)) |
                                (rot_data_a >> rot_bits);
    end
  endfunction

  function automatic logic [7:0] get_left_flush_byte(input logic [11:0] index);
    logic [7:0] value;
    begin
      value = '0;
      if (is_shift) begin
        if (shift_partial && index == 0)
          value = last_data << shift_value[2:0];
      end else if (!shift_partial) begin
        value = first_data_a;
      end else if (index == 0) begin
        value = (last_data << shift_value[2:0]) |
                (first_data_b >> (8 - shift_value[2:0]));
      end else begin
        value = (first_data_a << shift_value[2:0]) |
                (first_data_b >> (8 - shift_value[2:0]));
      end
      get_left_flush_byte = value;
    end
  endfunction

  always_comb begin
    first_addr_a = flush_index[10:0] - (shift_partial ? 11'd1 : 11'd0);
    first_addr_b = flush_index[10:0];
    if (state == ST_SHORT_SHIFT_FETCH || state == ST_SHORT_SHIFT_OUT) begin
      first_addr_a = output_index[10:0] + shift_bytes;
      first_addr_b = output_index[10:0] + shift_bytes + 11'd1;
    end else if (state == ST_SHORT_ROT_FETCH || state == ST_SHORT_ROT_OUT) begin
      first_addr_a = rot_a[10:0];
      first_addr_b = rot_b[10:0];
    end
  end

  always_ff @(posedge i_clk) begin
    first_data_a <= first_mem_a[first_addr_a];
    first_data_b <= first_mem_b[first_addr_b];
    if (!i_rst && state == ST_STREAM && i_valid && read_index < lookahead_bytes) begin
      first_mem_a[read_index[10:0]] <= i_data;
      first_mem_b[read_index[10:0]] <= i_data;
    end
  end

  always_ff @(posedge i_clk) begin
    if (i_rst)
      state <= ST_WAIT;
    else
      state <= next_state;
  end

  always_ff @(posedge i_clk) begin
    if (state == ST_STREAM && i_valid) begin
      right_mem_a[read_index[10:0]] <= i_data;
      right_mem_b[read_index[10:0]] <= i_data;
      rot_mem_a[read_index] <= i_data;
      rot_mem_b[read_index] <= i_data;
    end
    rot_data_a <= rot_mem_a[rot_read_addr_a];
    rot_data_b <= rot_mem_b[rot_read_addr_b];
  end

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      control_1 <= '0;
      control_0 <= '0;
      read_index <= '0;
      output_index <= '0;
      flush_index <= '0;
      data_count <= '0;
      last_data <= '0;
      rot_a <= '0;
      rot_b <= '0;
      rot_read_addr_a <= '0;
      rot_read_addr_b <= '0;
      rot_bits <= '0;
      remaining_shift <= '0;
    end else begin
      case (state)
        ST_WAIT: begin
          read_index <= '0;
          output_index <= '0;
          flush_index <= '0;
          data_count <= '0;
          if (i_valid && i_first)
            control_1 <= i_data;
        end

        ST_CTRL_0: begin
          if (i_valid)
            control_0 <= i_data;
        end

        ST_STREAM: begin
          if (i_valid) begin
            last_data <= i_data;
            if (i_last) begin
              data_count <= read_index + 13'd1;
              output_index <= '0;
              flush_index <= '0;
              remaining_shift <= {2'b0, shift_value};
            end else begin
              read_index <= read_index + 1'b1;
            end
          end
        end

        ST_LEFT_FLUSH: begin
          if (flush_index != lookahead_bytes - 1'b1)
            flush_index <= flush_index + 1'b1;
        end

        ST_SHORT_SHIFT_OUT: begin
          if (output_index != data_count - 1'b1)
            output_index <= output_index + 1'b1;
        end

        ST_SHORT_ROT_PREP,
        ST_ROT_RIGHT_PREP: begin
          if (remaining_shift >= {data_count, 3'b000}) begin
            remaining_shift <= remaining_shift - {data_count, 3'b000};
          end else begin
            rot_bits <= remaining_shift[2:0];
            if (state == ST_SHORT_ROT_PREP) begin
              rot_a <= remaining_shift[14:3];
              if (remaining_shift[14:3] == data_count - 1'b1)
                rot_b <= '0;
              else
                rot_b <= remaining_shift[14:3] + 1'b1;
            end else begin
              if (remaining_shift[14:3] == 0) begin
                rot_a <= '0;
                rot_b <= data_count - 1'b1;
                rot_read_addr_a <= '0;
                rot_read_addr_b <= data_count - 1'b1;
              end else begin
                rot_a <= data_count - remaining_shift[14:3];
                rot_b <= data_count - remaining_shift[14:3] - 1'b1;
                rot_read_addr_a <= data_count - remaining_shift[14:3];
                rot_read_addr_b <= data_count - remaining_shift[14:3] - 1'b1;
              end
            end
          end
        end

        ST_ROT_RIGHT_PRIME: begin
          if (rot_a == data_count - 1'b1)
            rot_read_addr_a <= '0;
          else
            rot_read_addr_a <= rot_a + 1'b1;
          if (rot_b == data_count - 1'b1)
            rot_read_addr_b <= '0;
          else
            rot_read_addr_b <= rot_b + 1'b1;
        end

        ST_SHORT_ROT_OUT,
      ST_ROT_RIGHT_OUT: begin
          if (output_index != data_count - 1'b1) begin
            output_index <= output_index + 1'b1;
            if (rot_a == data_count - 1'b1)
              rot_a <= '0;
            else
              rot_a <= rot_a + 1'b1;
            if (rot_b == data_count - 1'b1)
              rot_b <= '0;
            else
              rot_b <= rot_b + 1'b1;
            if (state == ST_ROT_RIGHT_OUT) begin
              if (rot_read_addr_a == data_count - 1'b1)
                rot_read_addr_a <= '0;
              else
                rot_read_addr_a <= rot_read_addr_a + 1'b1;
              if (rot_read_addr_b == data_count - 1'b1)
                rot_read_addr_b <= '0;
              else
                rot_read_addr_b <= rot_read_addr_b + 1'b1;
            end
          end
        end

        ST_LEFT_FLUSH_FETCH, ST_SHORT_SHIFT_FETCH, ST_SHORT_ROT_FETCH: begin end

        default: begin
          read_index <= '0;
          output_index <= '0;
          flush_index <= '0;
          data_count <= '0;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    o_valid = 1'b0;
    o_last = 1'b0;
    o_data = '0;

    case (state)
      ST_WAIT: begin
        if (i_valid && i_first)
          next_state = ST_CTRL_0;
      end

      ST_CTRL_0: begin
        if (i_valid)
          next_state = ST_STREAM;
      end

      ST_STREAM: begin
        if (i_valid) begin
          if (is_shift && is_right) begin
            o_valid = 1'b1;
            o_data = get_right_stream_byte(read_index, i_data);
            o_last = i_last;
          end else if ((is_shift || is_rotate) && is_left &&
                       (read_index >= lookahead_bytes)) begin
            o_valid = 1'b1;
            o_data = get_left_stream_byte(i_data);
            o_last = i_last && (lookahead_bytes == 0);
          end

          if (i_last) begin
            if (is_rotate && is_right) begin
              next_state = ST_ROT_RIGHT_PREP;
            end else if ((is_shift || is_rotate) && is_left) begin
              if (read_index < lookahead_bytes) begin
                if (is_shift)
                  next_state = ST_SHORT_SHIFT_FETCH;
                else
                  next_state = ST_SHORT_ROT_PREP;
              end
              else if (lookahead_bytes != 0)
                next_state = ST_LEFT_FLUSH_FETCH;
              else
                next_state = ST_WAIT;
            end else begin
              next_state = ST_WAIT;
            end
          end
        end
      end

      ST_LEFT_FLUSH: begin
        o_valid = 1'b1;
        o_data = get_left_flush_byte(flush_index);
        o_last = (flush_index == lookahead_bytes - 1'b1);
        if (o_last)
          next_state = ST_WAIT;
        else
          next_state = ST_LEFT_FLUSH_FETCH;
      end

      ST_SHORT_SHIFT_OUT: begin
        o_valid = 1'b1;
        o_data = get_short_shift_byte(output_index);
        o_last = (output_index == data_count - 1'b1);
        if (o_last)
          next_state = ST_WAIT;
        else
          next_state = ST_SHORT_SHIFT_FETCH;
      end

      ST_SHORT_ROT_PREP: begin
        if (remaining_shift < {data_count, 3'b000})
          next_state = ST_SHORT_ROT_FETCH;
      end

      ST_SHORT_ROT_OUT: begin
        o_valid = 1'b1;
        o_data = get_short_rotate_left_byte();
        o_last = (output_index == data_count - 1'b1);
        if (o_last)
          next_state = ST_WAIT;
        else
          next_state = ST_SHORT_ROT_FETCH;
      end

      ST_LEFT_FLUSH_FETCH: next_state = ST_LEFT_FLUSH;
      ST_SHORT_SHIFT_FETCH: next_state = ST_SHORT_SHIFT_OUT;
      ST_SHORT_ROT_FETCH: next_state = ST_SHORT_ROT_OUT;

      ST_ROT_RIGHT_PREP: begin
        if (remaining_shift < {data_count, 3'b000})
          next_state = ST_ROT_RIGHT_PRIME;
      end

      ST_ROT_RIGHT_PRIME: begin
        next_state = ST_ROT_RIGHT_OUT;
      end

      ST_ROT_RIGHT_OUT: begin
        o_valid = 1'b1;
        o_data = get_rotate_right_byte();
        o_last = (output_index == data_count - 1'b1);
        if (o_last)
          next_state = ST_WAIT;
      end

      default: next_state = ST_WAIT;
    endcase
  end

endmodule
