//apb driver

class apb_driver extends uvm_driver;
`uvm_component_utils(apb_driver)

virtual apb_interface.APB_DRV_MP vif;
virtual reset_interface rst_intf;

apb_agt_config apb_cfg;
function new(string name="apb_driver",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
if(!uvm_config_db#(apb_agt_config)::get(this,"","apb_agt_config",apb_cfg))
`uvm_fatal("FATAL","FROM APB_DRIVER CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
endfunction

function void connect_phase(uvm_phase phase);
vif= apb_cfg.apb_intf;
endfunction
endclass