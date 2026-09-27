`timescale 1ns/1ps
module tb_general;
  reg clk=0; always #5 clk=~clk;
  reg rst=1,valid=0,first=0,last=0;
  reg [7:0] data=0;
  wire ov,ol; wire [7:0] od;
  task_15 dut(clk,rst,valid,first,last,data,ov,ol,od);
  bit h[0:15][0:31];
  bit golden[0:4095];
  integer count,received,errors=0,case_errors,cycles,cases=0;
  always @(posedge clk) begin
    #1;
    if(!rst && ov) begin
      if(received>=count || od !== {7'b0,golden[received]} || ol !== (received==count-1)) begin
        if(case_errors<4) $display("MISMATCH byte=%0d actual=%h expected=%b last=%b",received,od,golden[received],ol);
        case_errors++; errors++;
      end
      received++;
    end
  end
  task automatic send(input integer value,input bit f,input bit l,input integer gap);
    begin
      repeat(gap) begin @(negedge clk);valid=0;first=0;last=0;end
      @(negedge clk);valid=1;first=f;last=l;data=value;
    end
  endtask
  task automatic check_case(input integer m,input integer n,input integer variant);
    integer word,r,c,k; bit syndrome,ok,t;
    begin
      @(negedge clk); rst=(cases==0);valid=0;first=0;last=0;
      repeat(4) @(negedge clk);
      k=n-m; received=0;count=0;case_errors=0;
      for(r=0;r<m;r++) for(c=0;c<n;c++)
        h[r][c]=(c<k)?(((r*7+c*3+r*c)%5)<2):(c-k==r);
      if(variant>=3) for(r=0;r<m;r++) for(c=0;c<k;c++) h[r][c]=$urandom_range(0,1);
      // Invertible row operations preserve exactly the same codewords.
      if(variant>=1 && m>=3) begin
        for(c=0;c<n;c++) h[0][c]=h[0][c]^h[1][c];
        for(c=0;c<n;c++) begin t=h[1][c];h[1][c]=h[2][c];h[2][c]=t;end
      end
      if(variant>=2) for(r=0;r<m;r++) begin t=h[r][0];h[r][0]=h[r][n-1];h[r][n-1]=t;end
      // Independent oracle: enumerate all n-bit vectors, retain H*c^T=0.
      for(word=0;word<(1<<n);word++) begin
        ok=1;
        for(r=0;r<m;r++) begin
          syndrome=0;
          for(c=0;c<n;c++) syndrome^=h[r][c]&((word>>(n-1-c))&1);
          if(syndrome) ok=0;
        end
        if(ok) for(c=0;c<n;c++) begin golden[count]=(word>>(n-1-c))&1;count++;end
      end
      rst=0;
      send(m,1,0,0);send(n,0,0,0);
      for(r=0;r<m;r++) for(c=0;c<n;c++) send(h[r][c],0,(r==m-1&&c==n-1),(c%5==3));
      @(negedge clk);valid=0;first=0;last=0;
      cycles=0;
      while(received<count && cycles<50000) begin @(negedge clk);cycles++;end
      if(received!=count) begin errors++;case_errors++;end
      repeat(8) @(negedge clk);
      $display("CASE m=%0d n=%0d variant=%0d bytes=%0d/%0d errors=%0d cycles=%0d",m,n,variant,received,count,case_errors,cycles);
      cases++;
    end
  endtask
  initial begin
    for(integer v=0;v<3;v++) begin check_case(10,14,v);check_case(5,12,v);end
    for(integer m=1;m<=13;m++) for(integer n=m+1;n<=17;n++)
      if(2+m*n>=14 && 2+m*n<=198 && n*(1<<(n-m))>=136 && n*(1<<(n-m))<=3592)
        check_case(m,n,3);
    $display("GENERAL_SUMMARY cases=%0d errors=%0d",cases,errors);
    if(errors) $fatal(1,"GENERAL_FAIL");
    $display("GENERAL_PASS");$finish;
  end
endmodule
