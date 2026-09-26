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

  typedef enum logic [1:0] {
    ST_WAIT,
    ST_CTRL_0,
    ST_READ,
    ST_WRITE
  } state_t;

  state_t state, next_state;

  logic [7:0] control_1;
  logic [7:0] control_0;
  logic [7:0] data_mem [0:MAX_DATA_BYTES-1];
  logic [11:0] read_index;
  logic [11:0] write_index;
  logic [12:0] data_count;

  function automatic logic [7:0] get_output_byte(input logic [11:0] byte_index);
    logic [7:0] value;
    integer bit_index;
    integer source_bit;
    integer total_bits;
    integer shift_value;
    integer rotate_value;
    begin
      value = '0;
      total_bits = data_count * 8;
      shift_value = {control_1[3:0], control_0};

      if (total_bits != 0)
        rotate_value = shift_value % total_bits;
      else
        rotate_value = 0;

      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        source_bit = byte_index * 8 + bit_index;

        case (control_1[7:4])
          4'b0101: source_bit = source_bit + shift_value;
          4'b0110: source_bit = source_bit - shift_value;
          4'b1001: source_bit = (source_bit + rotate_value) % total_bits;
          4'b1010: source_bit = (source_bit + total_bits - rotate_value) % total_bits;
          default: source_bit = source_bit;
        endcase

        if ((source_bit >= 0) && (source_bit < total_bits))
          value[7-bit_index] = data_mem[source_bit / 8][7-(source_bit % 8)];
      end

      get_output_byte = value;
    end
  endfunction

  always_ff @(posedge i_clk) begin
    if (i_rst)
      state <= ST_WAIT;
    else
      state <= next_state;
  end

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      control_1  <= '0;
      control_0  <= '0;
      read_index <= '0;
      write_index <= '0;
      data_count <= '0;
    end else begin
      case (state)
        ST_WAIT: begin
          read_index  <= '0;
          write_index <= '0;
          data_count  <= '0;
          if (i_valid && i_first)
            control_1 <= i_data;
        end

        ST_CTRL_0: begin
          if (i_valid)
            control_0 <= i_data;
        end

        ST_READ: begin
          if (i_valid) begin
            data_mem[read_index] <= i_data;
            if (i_last) begin
              data_count  <= read_index + 13'd1;
              write_index <= '0;
            end else begin
              read_index <= read_index + 1'b1;
            end
          end
        end

        ST_WRITE: begin
          if (write_index != data_count - 1'b1)
            write_index <= write_index + 1'b1;
        end

        default: begin
          read_index  <= '0;
          write_index <= '0;
          data_count  <= '0;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    o_valid = 1'b0;
    o_last  = 1'b0;
    o_data  = '0;

    case (state)
      ST_WAIT: begin
        if (i_valid && i_first)
          next_state = ST_CTRL_0;
      end

      ST_CTRL_0: begin
        if (i_valid)
          next_state = ST_READ;
      end

      ST_READ: begin
        if (i_valid && i_last)
          next_state = ST_WRITE;
      end

      ST_WRITE: begin
        o_valid = 1'b1;
        o_data  = get_output_byte(write_index);
        o_last  = (write_index == data_count - 1'b1);
        if (o_last)
          next_state = ST_WAIT;
      end

      default: next_state = ST_WAIT;
    endcase
  end

endmodule
