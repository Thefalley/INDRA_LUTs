`timescale 1ns / 1ps
module task_8 #(
    parameter int TASK_INPUT_WIDTH  = 8,
    parameter int TASK_OUTPUT_WIDTH = 8,
    parameter int INPUT_STREAMS     = 1,
    parameter int OUTPUT_STREAMS    = 1

)(
    input i_clk,
    input i_rst,
    input i_first,
    input i_last,
    input [TASK_INPUT_WIDTH-1:0] i_data,
    input i_valid,
    output reg [TASK_OUTPUT_WIDTH-1:0] o_data,
    output reg o_last,
    output reg o_valid
);

  typedef enum logic [2:0] {LOAD,CALC,COPY,SEND} state_t;
  logic cells[0:4095], next_cells[0:4095];
  logic [7:0] generations, generation, load_byte;
  logic [5:0] row,column;
  logic [11:0] copy_address;
  logic [8:0] send_byte;
  state_t state;
  integer k,n;
  function automatic [3:0] neighbours(input integer r,input integer c);
    integer dr,dc,rr,cc; begin neighbours=0; for(dr=-1;dr<=1;dr=dr+1)for(dc=-1;dc<=1;dc=dc+1)if(dr!=0||dc!=0)begin rr=r+dr;cc=c+dc;if(rr>=0&&rr<64&&cc>=0&&cc<64)neighbours=neighbours+cells[rr*64+cc];end end
  endfunction
  function automatic [7:0] packed_byte(input integer b);
    integer q; begin for(q=0;q<8;q=q+1) packed_byte[7-q]=cells[b*8+q]; end
  endfunction
  always @(posedge i_clk) begin
    if(i_rst) begin state<=LOAD;load_byte<=0;generation<=0;o_valid<=0;o_last<=0;end else begin
      o_valid<=0;o_last<=0;
      case(state)
        LOAD: if(i_valid) begin
          if(i_first) begin generations<=i_data;load_byte<=0;end
          else begin for(k=0;k<8;k=k+1) cells[load_byte*8+k]<=i_data[7-k];load_byte<=load_byte+1;if(i_last)begin row<=0;column<=0;generation<=0;state<=CALC;end end
        end
        CALC: begin
          n=neighbours(row,column);next_cells[row*64+column]<= (n==3)||(cells[row*64+column]&&n==2);
          if(row==63&&column==63) begin copy_address<=0;state<=COPY;end else if(column==63)begin column<=0;row<=row+1;end else column<=column+1;
        end
        COPY: begin cells[copy_address]<=next_cells[copy_address];if(copy_address==4095)begin if(generation+1>=generations)begin send_byte<=0;state<=SEND;end else begin generation<=generation+1;row<=0;column<=0;state<=CALC;end end else copy_address<=copy_address+1;end
        SEND: begin o_data<=packed_byte(send_byte);o_valid<=1;if(send_byte==511)begin o_last<=1;state<=LOAD;end else send_byte<=send_byte+1;end
      endcase
    end
  end


endmodule
