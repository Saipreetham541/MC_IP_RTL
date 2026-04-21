//apb monitor
class apb_monitor extends uvm_monitor;
 `uvm_component_utils(apb_monitor)
 apb_agt_config apb_cfg; 
 
 virtual apb_interface.APB_MON_MP vif;
 virtual reset_interface rst_intf;
 function new(string name="apb_monitor",uvm_component parent);
 super.new(name,parent);
 endfunction
 
 function void build_phase(uvm_phase phase);
if(!uvm_config_db#(apb_agt_config)::get(this,"","apb_agt_config",apb_cfg))
`uvm_fatal("FATAL","FROM APB_MONITOR CLASS")
if(!uvm_config_db #(virtual reset_interface)::get(this,"","rst_intf",rst_intf))
`uvm_fatal("FATAL","FROM RESET INTERFACE")
endfunction

function void connect_phase(uvm_phase phase);
vif=apb_cfg.apb_intf;
endfunction
 
 endclass