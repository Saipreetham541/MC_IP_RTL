//apb_interface

interface apb_interface(input bit apb_clk);
logic apb_rst_n;
logic global_reset;

logic [15:0] paddr;
logic psel;
logic penable;
logic pwrite;
logic [31:0]pwdata;
logic [3:0]pstrb;
logic [31:0]prdata;
logic pready;
logic pslverr;
//apb_driving clocking block

clocking apb_drv_cb@(posedge apb_clk);
output paddr,psel,penable,pwrite,pwdata,pstrb;
input prdata,pready,pslverr;
endclocking

//apb_monitor clocking block
clocking apb_mon_cb@(posedge apb_clk);
input paddr,psel,penable,pwrite,pwdata,pstrb;
input prdata,pready,pslverr;
endclocking


modport APB_DRV_MP(clocking apb_drv_cb);
modport APB_MON_MP(clocking apb_mon_cb);
endinterface