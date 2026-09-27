`timescale 1ns/1ps
module tb_task9_extended;
  logic clk=0, rst=1, iv=0, ifirst=0, il=0;
  logic [31:0] id=0;
  wire ov,of,ol;
  wire [31:0] od;
  always #5 clk=~clk;
  task_9 dut(.i_clk(clk),.i_rst(rst),.i_valid(iv),.i_first(ifirst),.i_last(il),.i_data(id),
             .o_valid(ov),.o_first(of),.o_last(ol),.o_data(od));
  logic [31:0] inputs[0:4095], expected[0:65535];
  longint signed a[0:63][0:63],b[0:63][0:63],s[0:3],mag;
  int ni,no,count,errors=0,cases=0,cycles=0,start_cycle,last_input,last_output;
  int nr,na,nb,np,ex,v,shift,local_shift,seed=90321;
  bit capture=0;
  always @(posedge clk) begin
    cycles++;
    if(capture && ov) begin
      if(count>=no || od!==expected[count] || of!==(count==0) || ol!==(count==no-1)) begin
        if(errors<10) $display("MISMATCH case=%0d word=%0d got=%h expected=%h first=%b last=%b",cases,count,od,expected[count],of,ol);
        errors++;
      end
      count++;
      last_output=cycles;
    end
    if(capture && !ov && (of||ol)) errors++;
  end
  initial begin
    repeat(4) @(negedge clk); rst=0;
    for(int t=0;t<46;t++) begin
      case(t)
        0: begin nr=64;na=64;nb=64;np=1;end
        1: begin nr=62;na=64;nb=64;np=1;end
        2: begin nr=6;na=6;nb=10;np=5;end
        3: begin nr=2;na=2;nb=2;np=255;end
        4: begin nr=64;na=2;nb=2;np=16;end
        45: begin nr=2;na=64;nb=64;np=32;end
        default: begin nr=2+2*(t%16);na=2+2*(t%9);nb=2+2*((t*3)%8);np=1+t%3;end
      endcase
      ni=1;no=1;inputs[0]=(np<<24)|(nr<<16)|(na<<8)|nb;
      expected[0]=(np<<24)|(nb<<16)|na;
      for(int pair=0;pair<np;pair++) begin
        for(int factor=0;factor<2;factor++) begin
          for(int c=0;c<(factor?nb:na);c+=2) for(int r=0;r<nr;r+=2) begin
            ex=$urandom(seed)%4;inputs[ni]=ex;
            for(int k=0;k<4;k++) begin
              v=int'($urandom(seed)%17)-8;
              inputs[ni]|=(v&127)<<(4+7*k);
              if(factor) b[r+k/2][c+k%2]=longint'(v)<<<ex;
              else a[r+k/2][c+k%2]=longint'(v)<<<ex;
            end
            ni++;
          end
        end
        for(int ca=0;ca<na;ca+=2) for(int cb=0;cb<nb;cb+=2) begin
          shift=0;
          for(int k=0;k<4;k++) begin
            s[k]=0;
            for(int r=0;r<nr;r++) s[k]+=a[r][ca+k%2]*b[r][cb+k/2];
            mag=(s[k]<0)?-s[k]:s[k];local_shift=0;
            while(mag>63) begin mag=mag>>1;local_shift++;end
            if(local_shift>shift) shift=local_shift;
          end
          if(shift>15) $fatal(1,"Reference outside exponent range");
          expected[no]=shift;
          for(int k=0;k<4;k++) expected[no]|=((s[k]>>>shift)&127)<<(4+7*k);
          no++;
        end
      end
      if(ni>2049) $fatal(1,"Input exceeds contract");
      @(negedge clk);capture=1;count=0;start_cycle=cycles;
      for(int i=0;i<ni;i++) begin
        iv=1;ifirst=(i==0);il=(i==ni-1);id=inputs[i];
        @(negedge clk);
        if(t%2 && i%5==2) begin iv=0;ifirst=0;il=0;repeat(2) @(negedge clk);end
      end
      last_input=cycles;iv=0;ifirst=0;il=0;
      while(count<no && cycles-last_input<200000) @(negedge clk);
      repeat(4) @(negedge clk);capture=0;
      if(count!=no) $fatal(1,"Timeout count=%0d expected=%0d",count,no);
      $display("EXTENDED case=%0d dims=%0dx%0dx%0d pairs=%0d inputs=%0d outputs=%0d from_last=%0d total_cycles=%0d errors=%0d",t,nr,na,nb,np,ni,no,last_output-last_input,last_output-start_cycle,errors);
      cases++;
    end
    $display("TASK9_EXTENDED cases=%0d errors=%0d",cases,errors);
    if(errors) $fatal(1,"Regression failed");
    $finish;
  end
endmodule
