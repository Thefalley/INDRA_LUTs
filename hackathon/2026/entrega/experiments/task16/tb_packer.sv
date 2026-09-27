`timescale 1ns/1ps
module tb_packer;
  logic i_clk=0, i_rst=1;
  always #5 i_clk=~i_clk;
  logic i_valid=0, i_last=0, i_ready, o_valid, o_last, o_ready=0;
  logic [31:0] i_data=0, o_data;
  logic [3:0] i_keep=0, o_keep;
  task_16 dut(.*);

  byte unsigned expected[0:2047];
  logic [31:0] words[0:511];
  logic [3:0] keeps[0:511];
  integer expected_len=0, received=0, last_count=0, case_id=0;
  integer total_cycles=0, total_bytes=0, cycles, beats, mode;
  integer sent, n, b, j, seed=32'h16320409;
  integer mode_cycles[0:3];
  bit active=0, held=0;
  logic [36:0] held_value;

  function automatic logic [3:0] keep_for(input integer count);
    case(count)
      1: return 4'h1;
      2: return 4'h3;
      3: return 4'h7;
      default: return 4'hf;
    endcase
  endfunction

  always @(posedge i_clk) begin
    if (i_rst) held=0;
    else begin
      if (held && (!o_valid || {o_last,o_keep,o_data} !== held_value))
        $fatal(1,"case=%0d output changed under backpressure",case_id);
      held=o_valid && !o_ready;
      held_value={o_last,o_keep,o_data};
      if (o_valid && o_ready) begin
        if (!active) $fatal(1,"unexpected output outside packet");
        if (!(o_keep inside {4'h1,4'h3,4'h7,4'hf})) $fatal(1,"bad keep");
        if (!o_last && o_keep != 4'hf) $fatal(1,"partial non-final beat");
        for (integer lane=0;lane<4;lane++) begin
          if (o_keep[lane]) begin
            if (received>=expected_len) $fatal(1,"extra byte");
            if (o_data[8*lane+:8] !== expected[received])
              $fatal(1,"case=%0d byte=%0d got=%02x want=%02x",case_id,received,o_data[8*lane+:8],expected[received]);
            received=received+1;
          end
        end
        if (o_last) begin
          last_count=last_count+1;
          if (received!=expected_len) $fatal(1,"early last");
        end
      end
    end
  end

  initial begin
    seed=$urandom(seed);
    for (integer m=0;m<4;m++) mode_cycles[m]=0;
    repeat(4) @(negedge i_clk);
    i_rst=0;
    for (case_id=0;case_id<256;case_id++) begin
      seed=32'h16320409 ^ case_id;
      seed=$urandom(seed);
      mode=case_id%4;
      beats=(case_id<16) ? 4+case_id : ((case_id<32) ? 512 : $urandom_range(4,512));
      expected_len=0;
      for (j=0;j<beats;j++) begin
        words[j]=$urandom;
        case(mode)
          0: n=3;
          1: n=(j%4)+1;
          2: n=$urandom_range(1,4);
          3: n=4;
        endcase
        keeps[j]=keep_for(n);
        for (b=0;b<n;b++) begin
          expected[expected_len]=words[j][8*b+:8];
          expected_len=expected_len+1;
        end
      end
      received=0; last_count=0; sent=0; cycles=0; active=1;
      while(last_count==0) begin
        @(negedge i_clk);
        o_ready=(mode!=2) || ($urandom_range(0,7)>2);
        if (!i_valid) begin
          if (sent<beats && ((mode!=2)||$urandom_range(0,1))) begin
            i_valid=1; i_data=words[sent]; i_keep=keeps[sent]; i_last=(sent==beats-1);
          end
        end
        @(posedge i_clk);
        // Sample transfer before the DUT's nonblocking updates.
        if (i_valid && i_ready) sent=sent+1;
        if (i_valid && i_ready) begin
          // Clear only after this edge; the monitor sees unchanged data.
          #1; i_valid=0; i_last=0;
        end else #1;
        cycles=cycles+1;
        if(cycles>20000) $fatal(1,"timeout case=%0d sent=%0d received=%0d",case_id,sent,received);
      end
      @(negedge i_clk);
      i_valid=0; i_last=0; o_ready=1;
      repeat(4) @(negedge i_clk);
      if(last_count!=1 || received!=expected_len || sent!=beats) $fatal(1,"packet accounting");
      active=0;
      total_cycles=total_cycles+cycles;
      total_bytes=total_bytes+expected_len;
      mode_cycles[mode]=mode_cycles[mode]+cycles;
    end
    $display("PASS packets=%0d bytes=%0d cycles=%0d modes=%0d,%0d,%0d,%0d",case_id,total_bytes,total_cycles,mode_cycles[0],mode_cycles[1],mode_cycles[2],mode_cycles[3]);
    $finish;
  end
endmodule
