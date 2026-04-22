//`include "../interfaces/apb_interface.sv"
//`include "../interfaces/axi_mgr_interface.sv"
//`include "../interfaces/axi_sub_interface.sv"
//`include "../interfaces/fdi_interface.sv"
//`include "../interfaces/reset_interface.sv"

module axfdi_bridge_tb();

import uvm_pkg::*;
import axfdi_pkg::*;

logic axi_clk=0;
logic fdi_clk=0;
logic apb_clk=0;

reset_interface rst_intf();

mgr_interface axi_mgr_intf_0(axi_clk);
sub_interface axi_sub_intf_0(axi_clk);
mgr_interface axi_mgr_intf_1(axi_clk);
sub_interface axi_sub_intf_1(axi_clk);

fdi_interface fdi_intf(fdi_clk);
apb_interface apb_intf(apb_clk);
//DUT instantiation
axfdi_bridge DUV(.fdi_clk_i(fdi_clk),
                 .axi_clk_i(axi_clk),
                 .por_n_i(rst_intf.global_reset),
                 .axi_rst_n_i(rst_intf.axi_rst_n),                     
				 .fdi_rst_n_i(rst_intf.fdi_rst_n),
				 .PORT0_SUB_awaddr(axi_sub_intf_0.awaddr),
				 .PORT0_SUB_awid(axi_sub_intf_0.awid),
				 .PORT0_SUB_awlen(axi_sub_intf_0.awlen),
				 .PORT0_SUB_awsize(axi_sub_intf_0.awsize),
				 .PORT0_SUB_awburst(axi_sub_intf_0.awburst),
				 .PORT0_SUB_awvalid(axi_sub_intf_0.awvalid),
				 .PORT0_SUB_awready(axi_sub_intf_0.awready),
				 .PORT0_SUB_wdata(axi_sub_intf_0.wdata),
				 .PORT0_SUB_wstrb(axi_sub_intf_0.wstrb),                   
				 .PORT0_SUB_wlast(axi_sub_intf_0.wlast),
                 .PORT0_SUB_wvalid(axi_sub_intf_0.wvalid), 
                 .PORT0_SUB_wready(axi_sub_intf_0.wready),
				 .PORT0_SUB_bid(axi_sub_intf_0.bid) ,
				 .PORT0_SUB_bresp(axi_sub_intf_0.bresp),
                 .PORT0_SUB_bvalid(axi_sub_intf_0.bvalid),
                 .PORT0_SUB_bready(axi_sub_intf_0.bready),
				 .PORT0_SUB_araddr(axi_sub_intf_0.araddr),
				 .PORT0_SUB_arid(axi_sub_intf_0.arid),
				 .PORT0_SUB_arlen(axi_sub_intf_0.arlen),
                 .PORT0_SUB_arsize(axi_sub_intf_0.arsize),
                 .PORT0_SUB_arburst(axi_sub_intf_0.arburst),
                 .PORT0_SUB_arvalid(axi_sub_intf_0.arvalid),
                 .PORT0_SUB_arready(axi_sub_intf_0.arready),
				 .PORT0_SUB_rdata(axi_sub_intf_0.rdata),
				 .PORT0_SUB_rid(axi_sub_intf_0.rid),
				 .PORT0_SUB_rresp(axi_sub_intf_0.rresp),
                 .PORT0_SUB_rlast(axi_sub_intf_0.rlast),
                 .PORT0_SUB_rvalid(axi_sub_intf_0.rvalid),
                 .PORT0_SUB_rready(axi_sub_intf_0.rready),
				 .PORT1_SUB_awaddr(axi_sub_intf_1.awaddr),
                 .PORT1_SUB_awid(axi_sub_intf_1.awid),
                 .PORT1_SUB_awlen(axi_sub_intf_1.awlen),
				 .PORT1_SUB_awsize(axi_sub_intf_1.awsize),
                 .PORT1_SUB_awburst(axi_sub_intf_1.awburst),
                 .PORT1_SUB_awvalid(axi_sub_intf_1.awvalid),
                 .PORT1_SUB_awready(axi_sub_intf_1.awready),
				 .PORT1_SUB_wdata(axi_sub_intf_1.wdata),
                 .PORT1_SUB_wstrb(axi_sub_intf_1.wstrb),
                 .PORT1_SUB_wlast(axi_sub_intf_1.wlast),
                 .PORT1_SUB_wvalid(axi_sub_intf_1.wvalid),
                 .PORT1_SUB_wready(axi_sub_intf_1.wready),
				 .PORT1_SUB_bid(axi_sub_intf_1.bid) ,
                 .PORT1_SUB_bresp(axi_sub_intf_1.bresp),
                 .PORT1_SUB_bvalid(axi_sub_intf_1.bvalid),
                 .PORT1_SUB_bready(axi_sub_intf_1.bready),
				 .PORT1_SUB_araddr(axi_sub_intf_1.araddr),
				 .PORT1_SUB_arid(axi_sub_intf_1.arid),
                 .PORT1_SUB_arlen(axi_sub_intf_1.arlen),
				 .PORT1_SUB_arsize(axi_sub_intf_1.arsize),
				 .PORT1_SUB_arburst(axi_sub_intf_1.arburst),
                 .PORT1_SUB_arvalid(axi_sub_intf_1.arvalid),
                 .PORT1_SUB_arready(axi_sub_intf_1.arready),
				 .PORT1_SUB_rdata(axi_sub_intf_1.rdata),
				 .PORT1_SUB_rid(axi_sub_intf_1.rid),
				 .PORT1_SUB_rresp(axi_sub_intf_1.rresp),
                 .PORT1_SUB_rlast(axi_sub_intf_1.rlast),
                 .PORT1_SUB_rvalid(axi_sub_intf_1.rvalid),
                 .PORT1_SUB_rready(axi_sub_intf_1.rready),
			     .PORT0_MGR_awaddr(axi_mgr_intf_0.awaddr),
				 .PORT0_MGR_awid(axi_mgr_intf_0.awid),
				 .PORT0_MGR_awlen(axi_mgr_intf_0.awlen),
				 .PORT0_MGR_awsize(axi_mgr_intf_0.awsize),
				 .PORT0_MGR_awburst(axi_mgr_intf_0.awburst),
                 .PORT0_MGR_awvalid(axi_mgr_intf_0.awvalid),
                 .PORT0_MGR_awready(axi_mgr_intf_0.awready),
                 .PORT0_MGR_wdata(axi_mgr_intf_0.wdata),
				 .PORT0_MGR_wstrb(axi_mgr_intf_0.wstrb),
                 .PORT0_MGR_wlast(axi_mgr_intf_0.wlast),
                 .PORT0_MGR_wvalid(axi_mgr_intf_0.wvalid),
                 .PORT0_MGR_wready(axi_mgr_intf_0.wready),
                 .PORT0_MGR_bid(axi_mgr_intf_0.bid),
                 .PORT0_MGR_bresp(axi_mgr_intf_0.bresp),
                 .PORT0_MGR_bvalid(axi_mgr_intf_0.bvalid),
                 .PORT0_MGR_bready(axi_mgr_intf_0.bready),
                 .PORT0_MGR_araddr(axi_mgr_intf_0.araddr),
                 .PORT0_MGR_arid(axi_mgr_intf_0.arid),
                 .PORT0_MGR_arlen(axi_mgr_intf_0.arlen),
                 .PORT0_MGR_arsize(axi_mgr_intf_0.arsize),
                 .PORT0_MGR_arburst(axi_mgr_intf_0.arburst),
                 .PORT0_MGR_arvalid(axi_mgr_intf_0.arvalid),
                 .PORT0_MGR_arready(axi_mgr_intf_0.arready),
                 .PORT0_MGR_rdata(axi_mgr_intf_0.rdata),
                 .PORT0_MGR_rid(axi_mgr_intf_0.rid),
                 .PORT0_MGR_rresp(axi_mgr_intf_0.rresp),
                 .PORT0_MGR_rlast(axi_mgr_intf_0.rlast),
                 .PORT0_MGR_rvalid(axi_mgr_intf_0.rvalid),
                 .PORT0_MGR_rready(axi_mgr_intf_0.rready),
                 .PORT1_MGR_awaddr(axi_mgr_intf_1.awaddr),
                 .PORT1_MGR_awid(axi_mgr_intf_1.awid),
                 .PORT1_MGR_awlen(axi_mgr_intf_1.awlen),
                 .PORT1_MGR_awsize(axi_mgr_intf_1.awsize),
                 .PORT1_MGR_awburst(axi_mgr_intf_1.awburst),
                 .PORT1_MGR_awvalid(axi_mgr_intf_1.awvalid),
                 .PORT1_MGR_awready(axi_mgr_intf_1.awready),
                 .PORT1_MGR_wdata(axi_mgr_intf_1.wdata),
                 .PORT1_MGR_wstrb(axi_mgr_intf_1.wstrb),
                 .PORT1_MGR_wlast(axi_mgr_intf_1.wlast),
                 .PORT1_MGR_wvalid(axi_mgr_intf_1.wvalid),
                 .PORT1_MGR_wready(axi_mgr_intf_1.wready),
                 .PORT1_MGR_bid(axi_mgr_intf_1.bid) ,
                 .PORT1_MGR_bresp(axi_mgr_intf_1.bresp),
                 .PORT1_MGR_bvalid(axi_mgr_intf_1.bvalid),
                 .PORT1_MGR_bready(axi_mgr_intf_1.bready),
                 .PORT1_MGR_araddr(axi_mgr_intf_1.araddr),
                 .PORT1_MGR_arid(axi_mgr_intf_1.arid),
                 .PORT1_MGR_arlen(axi_mgr_intf_1.arlen),
                 .PORT1_MGR_arsize(axi_mgr_intf_1.arsize),
                 .PORT1_MGR_arburst(axi_mgr_intf_1.arburst),
                 .PORT1_MGR_arvalid(axi_mgr_intf_1.arvalid),
                 .PORT1_MGR_arready(axi_mgr_intf_1.arready),
                 .PORT1_MGR_rdata(axi_mgr_intf_1.rdata),
			     .PORT1_MGR_rid(axi_mgr_intf_1.rid),
                 .PORT1_MGR_rresp(axi_mgr_intf_1.rresp),
                 .PORT1_MGR_rlast(axi_mgr_intf_1.rlast),
                 .PORT1_MGR_rvalid(axi_mgr_intf_1.rvalid),
                 .PORT1_MGR_rready(axi_mgr_intf_1.rready),
                 .fdi_lp_data(fdi_intf.fdi_lp_data),
                 .fdi_lp_valid(fdi_intf.fdi_lp_valid),
                 .fdi_lp_irdy(fdi_intf.fdi_lp_irdy),
                 .fdi_lp_startofpkt(fdi_intf.fdi_lp_startofpkt),
                 .fdi_lp_endofpkt(fdi_intf.fdi_lp_endofpkt),
                 .fdi_pl_trdy(fdi_intf.fdi_pl_trdy),
                 .fdi_lp_state_req(fdi_intf.fdi_lp_state_req),
                 .fdi_lp_linkerror(fdi_intf.fdi_lp_link_error),
                 .fdi_pl_data(fdi_intf.fdi_pl_data),
                 .fdi_pl_valid(fdi_intf.fdi_pl_valid),
                 .fdi_pl_irdy(fdi_intf.fdi_pl_irdy),
                 .fdi_pl_startofpkt(fdi_intf.fdi_pl_startofpkt),
                 .fdi_pl_endofpkt(fdi_intf.fdi_pl_endofpkt),
                 .fdi_lp_trdy(fdi_intf.fdi_lp_trdy),
                 .fdi_pl_state_sts(fdi_intf.fdi_pl_state_sts),
                 .fdi_pl_inband_pres(fdi_intf.fdi_pl_inband_pres));
//axi_clk generation -500MHZ
always # 1.0 axi_clk=~axi_clk; 
//fdi_clk_generation -625 MHZ
always #0.8 fdi_clk=~fdi_clk;
//apb_clk_generation - <=200 MHZ
always #2.5 apb_clk=~apb_clk;
//connecct clocks to reset_interface
assign rst_intf.axi_clk=axi_clk;
assign rst_intf.fdi_clk=fdi_clk;
assign rst_intf.apb_clk=apb_clk;

assign axi_sub_intf_0.axi_rst_n=rst_intf.axi_rst_n;
assign axi_sub_intf_1.axi_rst_n=rst_intf.axi_rst_n;
assign axi_mgr_intf_0.axi_rst_n=rst_intf.axi_rst_n;
assign axi_mgr_intf_1.axi_rst_n=rst_intf.axi_rst_n;

assign fdi_intf.fdi_rst_n=rst_intf.fdi_rst_n;
assign apb_intf.apb_rst_n=rst_intf.apb_rst_n;


assign axi_sub_intf_0.global_reset=rst_intf.global_reset;
assign axi_sub_intf_1.global_reset=rst_intf.global_reset;
assign axi_mgr_intf_0.global_reset=rst_intf.global_reset;
assign axi_mgr_intf_1.global_reset=rst_intf.global_reset;

assign fdi_intf.global_reset=rst_intf.global_reset;
assign apb_intf.global_reset=rst_intf.global_reset;


initial
begin
   //waveform generation commands
   uvm_config_db #(virtual sub_interface)::set(null,"uvm_test_top.env.axi_agt[0]*","sub_vif",axi_sub_intf_0);  //setting axi_subordinate interface for port0
   uvm_config_db #(virtual sub_interface)::set(null,"uvm_test_top.env.axi_agt[1]*","sub_vif",axi_sub_intf_1); //setting axi_subordinate interface for port1
   uvm_config_db #(virtual mgr_interface)::set(null,"uvm_test_top.env.axi_agt[0]*","mgr_vif",axi_mgr_intf_0);  //setting axi_manager  interface for port 0
   uvm_config_db #(virtual mgr_interface)::set(null,"uvm_test_top.env.axi_agt[1]*","mgr_vif",axi_mgr_intf_1); //setting axi_manager interface for port1
   
   uvm_config_db #(virtual fdi_interface)::set(null,"*","in2",fdi_intf);  //setting fdi_interface
   
   uvm_config_db #(virtual apb_interface)::set(null,"*","in3",apb_intf);   //setting apb interface
   
   //global access for test-->so test can drive reset
   
   uvm_config_db #(virtual reset_interface)::set(null,"*","rst_intf",rst_intf);
   
   run_test();
   
end
endmodule
