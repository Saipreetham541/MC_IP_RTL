//apb AGENT
//import uvm_pkg::*;
//`include "uvm_macros.svh";
class apb_agent extends uvm_agent;
`uvm_component_utils(apb_agent)

apb_driver apb_drv;
apb_monitor apb_mon;
apb_sequencer apb_seqr;

apb_agt_config apb_cfg;


function new(string name="apb_agent",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db#(apb_agt_config)::get(this,"","apb_agt_config",apb_cfg))
`uvm_fatal("FATAL","FROM APB_AGENT")
apb_mon=apb_monitor::type_id::create("apb_mon",this);

if(apb_cfg.is_active)
begin
apb_drv=apb_driver::type_id::create("apb_drv",this);
apb_seqr=apb_sequencer::type_id::create("apb_seqr",this);
end
endfunction
endclass