`timescale 1ns/1ps
module tb_frame_local;
  logic clk64=0, rst_n=0, in_data=0;
  logic [2:0] divider=0;
  wire in_clk=divider[2];
  wire out_clk, out_data;
  always #7.8125 clk64=~clk64;
  always @(posedge clk64) divider<=divider+1'b1;
  serial_frame_extender dut(.*);
  logic [135:0] expected[0:1999], received=0;
  logic [7:0] header=0;
  logic [127:0] frame;
  int sent=0, checked=0, bits=0, errors=0, pos;
  bit synced=0;
  realtime input_start[0:1999], last_rise=0, last_fall=0;
  realtime recent_rises[0:7], output_start=0;
  always @(negedge out_clk) last_fall=$realtime;
  always @(posedge out_clk) if(rst_n) begin
    if(last_rise!=0 && ($realtime-last_rise<109 || $realtime-last_rise>126)) begin
      $display("BAD_CLOCK period=%f",$realtime-last_rise); errors++;
    end
    last_rise=$realtime;
    for(int h=0;h<7;h++) recent_rises[h]=recent_rises[h+1];
    recent_rises[7]=$realtime;
    if(!synced) begin
      header={header[6:0],out_data};
      if(header==8'h4e) begin
        synced=1; received=136'h4e; bits=8; output_start=recent_rises[0];
      end
    end else begin
      if(bits==0) output_start=$realtime;
      received={received[134:0],out_data}; bits++;
    end
    if(synced && bits==136) begin
      if(checked>=sent || received!==expected[checked]) begin
        if(errors<8) $display("FRAME_FAIL index=%0d got=%h expected=%h sent=%0d",checked,received,expected[checked],sent);
        errors++;
      end
      // Latency compares corresponding frame starts, not end-of-output
      // against start-of-input (which incorrectly includes serialization).
      if(output_start-input_start[checked]>32000) begin
        $display("LATENCY_FAIL frame=%0d",checked); errors++;
      end
      checked++; bits=0; received=0;
    end
  end
  initial begin
    repeat(13) @(negedge clk64); rst_n=1;
    for(int f=0;f<2000;f++) begin
      pos=f%120;
      frame=0; frame[127:120]=8'h4e; frame[119-pos]=1;
      expected[f]={frame,8'(pos)};
      for(int b=127;b>=0;b--) begin
        @(negedge in_clk); in_data=frame[b];
        if(b==127) input_start[f]=$realtime;
        @(posedge in_clk);
      end
      sent++;
    end
    @(negedge in_clk); in_data=0;
    wait(checked==2000);
    if(errors) $fatal(1,"LOCAL_FRAME_FAIL errors=%0d",errors);
    $display("LOCAL_FRAME_PASS frames=2000 all_positions=120 continuous_stream=1");
    $finish;
  end
  initial begin #33000000; $fatal(1,"TIMEOUT sent=%0d checked=%0d",sent,checked); end
endmodule
