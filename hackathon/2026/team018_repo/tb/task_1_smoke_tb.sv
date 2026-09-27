`timescale 1ns / 1ps
module task_1_smoke_tb;
  logic clk = 1'b0;
  logic rst = 1'b1;
  logic valid = 1'b0;
  logic first = 1'b0;
  logic last = 1'b0;
  logic [7:0] data = '0;
  logic out_valid;
  logic out_last;
  logic [7:0] out_data;
  logic [7:0] expected [0:3];
  integer output_index = 0;
  integer input_log;
  integer output_log;
  integer input_cycle = 0;
  integer output_cycle = 0;

  initial begin
    input_log = $fopen("logs/task_1_input_handshake.txt", "w");
    output_log = $fopen("logs/task_1_output_handshake.txt", "w");
    if ((input_log == 0) || (output_log == 0))
      $fatal(1, "Cannot open task_1 handshake logs");
  end

  task_1 dut (
    .i_clk(clk), .i_rst(rst), .i_valid(valid), .i_first(first), .i_last(last), .i_data(data),
    .o_valid(out_valid), .o_last(out_last), .o_data(out_data)
  );

  always #5 clk = ~clk;

  task send_byte(input logic [7:0] value, input logic is_first, input logic is_last);
    begin
      @(negedge clk);
      data = value;
      valid = 1'b1;
      first = is_first;
      last = is_last;
      input_cycle = input_cycle + 1;
      $fdisplay(input_log, "cycle=%0d time=%0t IN valid=1 first=%0b last=%0b data=%02h", input_cycle, $time, is_first, is_last, value);
      @(negedge clk);
      valid = 1'b0;
      first = 1'b0;
      last = 1'b0;
    end
  endtask

  always @(posedge clk) begin
    if (out_valid) begin
      output_cycle = output_cycle + 1;
      $fdisplay(output_log, "cycle=%0d time=%0t OUT valid=1 last=%0b data=%02h", output_cycle, $time, out_last, out_data);
      if (out_data !== expected[output_index])
        $fatal(1, "byte %0d: got %02h, expected %02h", output_index, out_data, expected[output_index]);
      if (out_last !== (output_index == 3))
        $fatal(1, "o_last incorrect on byte %0d", output_index);
      output_index = output_index + 1;
    end
  end

  initial begin
    expected[0] = 8'h91;
    expected[1] = 8'hA2;
    expected[2] = 8'hB3;
    expected[3] = 8'hC0;
    repeat (2) @(negedge clk);
    rst = 1'b0;
    send_byte(8'h90, 1'b1, 1'b0);
    send_byte(8'h03, 1'b0, 1'b0);
    send_byte(8'h12, 1'b0, 1'b0);
    send_byte(8'h34, 1'b0, 1'b0);
    send_byte(8'h56, 1'b0, 1'b0);
    send_byte(8'h78, 1'b0, 1'b1);
    wait (output_index == 4);
    $fclose(input_log);
    $fclose(output_log);
    $display("TASK_1_SMOKE_PASS");
    $finish;
  end
endmodule
