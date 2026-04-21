//fdi_interface
interface fdi_interface(input bit fdi_clk);
logic global_reset;
logic fdi_rst_n;

logic [2047:0]fdi_lp_data;
logic fdi_lp_valid;
logic fdi_lp_irdy;
logic fdi_lp_startofpkt;
logic fdi_lp_endofpkt;
logic fdi_pl_trdy;
logic [2:0] fdi_lp_state_req;
logic fdi_lp_link_error;
logic [2047:0]fdi_pl_data;
logic fdi_pl_valid;
logic fdi_pl_irdy;
logic fdi_pl_startofpkt;
logic fdi_pl_endofpkt;
logic fdi_lp_trdy;
logic [2:0] fdi_pl_state_sts;
logic fdi_pl_inband_pres;

//FDI_DRIVER clocking block
clocking fdi_drv_cb@(posedge fdi_clk);

output fdi_pl_data;
output fdi_pl_valid;
output fdi_pl_irdy;
output fdi_pl_startofpkt;
output fdi_pl_endofpkt;
output fdi_pl_state_sts;
output fdi_pl_inband_pres;
output fdi_pl_trdy;

input fdi_lp_trdy;
input fdi_lp_data;
input fdi_lp_valid;
input fdi_lp_irdy;
input fdi_lp_startofpkt;
input fdi_lp_state_req;
input fdi_lp_endofpkt;
input fdi_lp_link_error;
endclocking

//fdi_monitor clocking block
clocking fdi_mon_cb@(posedge fdi_clk);

input fdi_lp_data;
input fdi_lp_irdy;
input fdi_lp_valid;
input fdi_lp_startofpkt;
input fdi_lp_endofpkt;
input fdi_pl_trdy;
input fdi_lp_state_req;
input fdi_lp_link_error;
input fdi_pl_data;
input fdi_pl_valid;
input fdi_pl_irdy;
input fdi_pl_startofpkt;
input fdi_pl_endofpkt;
input fdi_lp_trdy;
input fdi_pl_state_sts;
input fdi_pl_inband_pres;
endclocking

modport FDI_DRV_MP(clocking fdi_drv_cb);
modport FDI_MON_MP(clocking fdi_mon_cb);

endinterface
