`timescale 1ns/1ps
module tb_stages;
  reg clk=0; always #5 clk=~clk;
  reg rst=1,valid=0,first=0,last=0;
  reg [7:0] data=0;
  wire ov,ol; wire [7:0] od;
  task_15 dut(.i_clk(clk),.i_rst(rst),.i_valid(valid),.i_first(first),.i_last(last),.i_data(data),.o_valid(ov),.o_last(ol),.o_data(od));
  reg [31:0] packet[0:31];
  reg [7:0] reference_bytes[0:207];
  integer cycles=0, outputs=0, words=0,errors=0,h_checks=0,g_checks=0;
  integer before_state, before_u;
  reg expected_bit, syndrome;
  function automatic bit h(input integer r,input integer c);
    integer idx;
    begin idx=2+r*13+c; h=packet[idx/4][8*(idx%4)]; end
  endfunction
  task automatic bad(input string message);
    begin errors++; $display("FAIL cycle=%0d %s",cycles,message); end
  endtask
  always @(posedge clk) begin
    before_state=dut.state; before_u=dut.u_counter;
    #1; cycles++;
    if(!rst) begin
      if(before_state==2 && dut.state==7) begin
        if(dut.h_rows!==9 || dut.n_bits!==13 || dut.k_bits!==4) bad("dimensions");
        for(integer r=0;r<9;r++) for(integer c=0;c<13;c++) begin
          h_checks++;
          if(dut.h_matrix[r][c] !== h(r,c)) bad($sformatf("H[%0d][%0d]",r,c));
        end
        $display("STAGE RX_H checked=%0d errors=%0d",h_checks,errors);
      end
      if(before_state==3 && dut.state==4) begin
        for(integer r=0;r<4;r++) begin
          $write("G row %0d: ",r);
          for(integer c=0;c<13;c++) begin
            expected_bit=(c<4)?(r==c):h(c-4,r);
            g_checks++;
            if(dut.g_matrix[r][c] !== expected_bit) bad($sformatf("G[%0d][%0d]",r,c));
            $write("%b",dut.g_matrix[r][c]);
          end
          $display("");
        end
        $display("STAGE BUILD_G checked=%0d errors=%0d",g_checks,errors);
      end
      if(before_state==4 && dut.state==5) begin
        words++;
        $write("ENCODE u=%04b c=",before_u[3:0]);
        for(integer c=0;c<13;c++) begin
          if(dut.current_codeword[c] !== reference_bytes[before_u*13+c][0]) bad("codeword versus official reference");
          $write("%b",dut.current_codeword[c]);
        end
        for(integer r=0;r<9;r++) begin
          syndrome=0;
          for(integer c=0;c<13;c++) syndrome=syndrome^(h(r,c)&dut.current_codeword[c]);
          if(syndrome!==0) bad("nonzero syndrome");
        end
        $display(" errors=%0d",errors);
      end
      if(before_state==5 && dut.state==6) begin
        for(integer j=0;j<208;j++) if(dut.out_mem[j] !== reference_bytes[j]) bad($sformatf("out_mem[%0d]",j));
        $display("STAGE WRITE_MEM checked=208 errors=%0d",errors);
      end
      if(ov) begin
        if(outputs>=208) bad("extra output");
        else if(od !== reference_bytes[outputs]) bad($sformatf("output[%0d] actual=%h expected=%h",outputs,od,reference_bytes[outputs]));
        if(ol !== (outputs==207)) bad("last position");
        outputs++;
      end else if(ol) bad("last without valid");
    end
  end
  initial begin
    $readmemh("tb/task15.mem",packet);
    $readmemh("tb/task15_ref.mem",reference_bytes);
    repeat(4) @(negedge clk); rst=0;
    for(integer j=0;j<119;j++) begin
      @(negedge clk); valid=1; first=(j==0); last=(j==118); data=packet[j/4]>>(8*(j%4));
    end
    @(negedge clk); valid=0;first=0;last=0;
    wait(outputs>=208); repeat(5) @(negedge clk);
    if(errors || outputs!=208 || words!=16 || h_checks!=117 || g_checks!=52) $fatal(1,"STAGE_CHECK_FAIL errors=%0d",errors);
    $display("STAGE_CHECK_PASS H=117 G=52 words=16 syndromes=144 memory=208 output=208 cycles=%0d",cycles);
    $finish;
  end
  initial begin #100000; $fatal(1,"TIMEOUT outputs=%0d",outputs); end
endmodule
