`timescale 1ns / 1ps
module task_5
#(
  parameter int TASK_INPUT_WIDTH = 8,
  parameter int TASK_OUTPUT_WIDTH = 16,
  parameter int INPUT_STREAMS     = 1,
  parameter int OUTPUT_STREAMS    = 1

)(
  input                         i_clk,
  input                         i_rst,

  input                         i_valid,
  input                         i_first,
  input                         i_last,
  input [TASK_INPUT_WIDTH-1:0]  i_data,

  output logic                  o_valid,
  output logic                  o_last,
  output logic [TASK_OUTPUT_WIDTH-1:0] o_data
);

  logic [15:0] trace [0:1023];
  logic [7:0] money, item, command;
  logic waiting_argument, sending;
  logic [10:0] count, final_count, read_count;
  integer added;

  function automatic [7:0] price(input [7:0] id);
    case(id) 8'hA1:price=15;8'hB2:price=20;8'hC3:price=2;8'hD4:price=75;default:price=18; endcase
  endfunction

  always_ff @(posedge i_clk) begin
    if(i_rst) begin money<=0;item<=0;command<=0;waiting_argument<=0;sending<=0;count<=0;final_count<=0;read_count<=0;o_valid<=0;o_last<=0;o_data<=0; end
    else begin
      o_valid<=0;o_last<=0;
      if(sending) begin
        o_data<=trace[read_count];o_valid<=1;
        if(read_count==final_count-1) begin o_last<=1;sending<=0;count<=0;waiting_argument<=0;money<=0;item<=0; end
        else read_count<=read_count+1;
      end else if(i_valid) begin
        if(i_first) begin trace[0]<=16'h0000;count<=1;money<=0;item<=0;waiting_argument<=0; end
        added=0;
        if(waiting_argument) begin
          if(command==8'hAA) begin
            item<=i_data; trace[count]<=16'h0100;trace[count+1]<=16'h0400;added=2;
            if(money>=price(i_data)) begin trace[count+2]<={8'h05,i_data};added=3;if(money>price(i_data)) begin trace[count+3]<={8'h06,money-price(i_data)};added=4;end money<=0;item<=0;end
          end else begin
            trace[count]<=16'h0300;trace[count+1]<=16'h0400;added=2;money<=money+i_data;
            if(item!=0 && money+i_data>=price(item)) begin trace[count+2]<={8'h05,item};added=3;if(money+i_data>price(item)) begin trace[count+3]<={8'h06,money+i_data-price(item)};added=4;end money<=0;item<=0;end
          end
          waiting_argument<=0;
        end else if(i_data==8'hAA || i_data==8'hBB) begin command<=i_data;waiting_argument<=1;end
        else if(i_data==8'hCC) begin if(money!=0) begin trace[count]<={8'h06,money};trace[count+1]<=16'h0000;added=2;end else begin trace[count]<=16'h0000;added=1;end money<=0;item<=0;end
        if(i_last) begin final_count<=count+added;read_count<=0;sending<=1;end else if(!i_first) count<=count+added;
      end
    end
  end


endmodule

