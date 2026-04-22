interface sub_interface(input bit axi_clk);
logic global_reset;
logic axi_rst_n;

logic [39:0] awaddr;
logic [7:0] awid;
logic [7:0]awlen;
logic [2:0] awsize;
logic [1:0] awburst;
logic awvalid;
logic awready;

//Declaration of Write Data Channel Signal
logic [1023:0] wdata;
logic [127:0] wstrb;
logic wlast;
logic wvalid;
logic wready;
	
//Declaration of Write Response Channel Signals
logic [7:0] bid;
logic [1:0] bresp;
logic bvalid;
logic bready;
	
//Declaration of Read Address Channel Signals
logic [7:0] arid;
logic [39:0] araddr;
logic [7:0] arlen;
logic [2:0] arsize;
logic [1:0] arburst;
logic  arvalid;
logic arready;
	
	
//Declaration of Read Data Channel Signals
logic [7:0] rid;
logic [1023:0] rdata;
logic [1:0] rresp;
logic rlast;
logic rvalid;
logic rready;
	
//subordinate driving clocking block

clocking sub_drv_cb @(posedge axi_clk);
//output global_reset;
//output axi_rst_n;

output awaddr,awid,awlen,awsize,awburst,awvalid;
output wdata,wstrb,wlast,wvalid;
output araddr,arid,arlen,arsize,arburst,arvalid;
output bready;
output rready;

input awready;
input wready;
input bid,bresp,bvalid;
input arready;
input rdata,rid,rresp,rlast,rvalid;
endclocking

//subordinate monitoring clocking block

clocking sub_mon_cb @(posedge axi_clk);

input awaddr,awid,awlen,awsize,awburst,awvalid;
input wdata,wstrb,wlast,wvalid;
input araddr,arid,arlen,arsize,arburst,arvalid;
input bready;
input rready;

input awready;
input wready;
input bid,bresp,bvalid;
input arready;
input rdata,rid,rresp,rlast,rvalid;
endclocking




modport SUB_DRV_MP (input global_reset,input axi_rst_n,clocking sub_drv_cb);
modport SUB_MON_MP (clocking sub_mon_cb);
endinterface