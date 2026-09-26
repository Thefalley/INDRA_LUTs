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
    WAIT_FIRST,
    READ_CTRL_0,
    READ_DATA,
    WRITE_DATA
  } state_t;

  state_t state;
  logic [7:0] control_1;
  logic [7:0] control_0;
  logic [7:0] data_mem [0:MAX_DATA_BYTES-1];
  integer read_index;
  integer write_index;
  integer data_bytes;

  function automatic logic [TASK_OUTPUT_WIDTH-1:0] transformed_byte(input integer byte_index);
    logic [TASK_OUTPUT_WIDTH-1:0] value;
    integer bit_index;
    integer source_bit;
    integer total_bits;
    integer shift_value;
    integer effective_shift;
    begin
      value = '0;
      total_bits = data_bytes * 8;
      shift_value = {control_1[3:0], control_0};
      if (total_bits != 0)
        effective_shift = shift_value % total_bits;
      else
        effective_shift = 0;

      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        source_bit = byte_index * 8 + bit_index;
        if (control_1[7:6] == 2'b01) begin
          if (control_1[5:4] == 2'b01)
            source_bit = byte_index * 8 + bit_index + shift_value;
          else if (control_1[5:4] == 2'b10)
            source_bit = byte_index * 8 + bit_index - shift_value;
        end else if (control_1[7:6] == 2'b10) begin
          if (control_1[5:4] == 2'b01)
            source_bit = (byte_index * 8 + bit_index + effective_shift) % total_bits;
          else if (control_1[5:4] == 2'b10)
            source_bit = (byte_index * 8 + bit_index + total_bits - effective_shift) % total_bits;
        end

        if ((source_bit >= 0) && (source_bit < total_bits))
          value[7-bit_index] = data_mem[source_bit / 8][7-(source_bit % 8)];
      end
      transformed_byte = value;
    end
  endfunction

  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      state       <= WAIT_FIRST;
      control_1   <= '0;
      control_0   <= '0;
      read_index  <= 0;
      write_index <= 0;
      data_bytes  <= 0;
      o_valid     <= 1'b0;
      o_last      <= 1'b0;
      o_data      <= '0;
    end else begin
      o_valid <= 1'b0;
      o_last  <= 1'b0;

      case (state)
        WAIT_FIRST: begin
          if (i_valid && i_first) begin
            control_1  <= i_data;
            read_index <= 0;
            state      <= READ_CTRL_0;
          end
        end

        READ_CTRL_0: begin
          if (i_valid) begin
            control_0 <= i_data;
            state     <= READ_DATA;
          end
        end

        READ_DATA: begin
          if (i_valid) begin
            data_mem[read_index] <= i_data;
            if (i_last) begin
              data_bytes  <= read_index + 1;
              write_index <= 0;
              state       <= WRITE_DATA;
            end else begin
              read_index <= read_index + 1;
            end
          end
        end

        WRITE_DATA: begin
          o_valid <= 1'b1;
          o_data  <= transformed_byte(write_index);
          o_last  <= (write_index == data_bytes - 1);
          if (write_index == data_bytes - 1)
            state <= WAIT_FIRST;
          else
            write_index <= write_index + 1;
        end

        default: state <= WAIT_FIRST;
      endcase
    end
  end

endmodule
