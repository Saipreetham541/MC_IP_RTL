module axfdi_bridge_tb();

import uvm_pkg::*;
import axfdi_pkg::*;

logic axi_clk;
logic fdi_clk;
logic apb_clk;

reset_interface rst_intf();



mgr_interface axi_mgr_intf_0(axi_clk);
sub_interface axi_sub_intf_0(axi_clk);
mgr_interface axi_mgr_intf_1(axi_clk);
sub_interface axi_sub_intf_1(axi_clk);

fdi_interface fdi_intf(fdi_clk);
apb_interface apb_intf(apb_clk);
//DUT instantiation

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
   
   run_test("axfdi_test");
   
end
endmodule
