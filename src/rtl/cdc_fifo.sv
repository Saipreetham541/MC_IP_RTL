module cdc_fifo#(parameter data_w=8,depth=8,addr_w=$clog2(depth))(
input clk_wr,clk_rd,rst,wr_en,rd_en,
input [data_w:0] data_in,
output reg [data_w:0] data_out,
output full,empty
);
reg [data_w:0] mem [0:depth-1];
reg [addr_w:0]wr_ptr,rd_ptr;//MSB is a wrap bit,[MSB-1:0] is used for addressing
wire [addr_w:0] wr_ptr_gray,rd_ptr_gray;
reg [addr_w:0]ff_wr1,ff_wr2,ff_rd1,ff_rd2;
wire [addr_w:0] wr_ptr_sync,rd_ptr_sync;

always @(posedge clk_wr or posedge rst)
begin
if(rst)
  wr_ptr<=0;
else if(wr_en && ~full)
  begin
  mem[wr_ptr[addr_w-1:0]]<=data_in;
  wr_ptr<=wr_ptr+1;
  end
end

always @(posedge clk_rd or posedge rst)
begin
if(rst)
   begin
   rd_ptr<=0;
   end
else if(rd_en && ~empty)
   begin
   data_out<=mem[rd_ptr[addr_w-1:0]];
   rd_ptr<=rd_ptr+1;
   end 
end

assign wr_ptr_gray= wr_ptr^(wr_ptr>>1);
assign rd_ptr_gray= rd_ptr^(rd_ptr>>1);

always @ (posedge clk_rd or posedge rst)
begin
if(rst)
  begin
  ff_rd1<=0;
  ff_rd2<=0;
  end
else
  begin
  ff_rd1<=wr_ptr_gray;
  ff_rd2<=ff_rd1;
  end 
end

always @(posedge clk_wr or posedge rst)
begin
if(rst)
  begin
  ff_wr1<=0;
  ff_wr2<=0;
  end
else
  begin
  ff_wr1<=rd_ptr_gray;
  ff_wr2<=ff_wr1;
  end
end

assign wr_ptr_sync=ff_rd2;
assign rd_ptr_sync=ff_wr2;

assign empty= (wr_ptr_sync == rd_ptr_gray);


wire [addr_w:0] wr_ptr_next_gray;
assign wr_ptr_next_gray= {~wr_ptr_gray [addr_w:addr_w-1],wr_ptr_gray[addr_w-2:0]};
assign full = (wr_ptr_next_gray == rd_ptr_sync);
endmodule