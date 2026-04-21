//fdi_agent
//import uvm_pkg::*;
//`include "uvm_macros.svh";
class fdi_agent extends uvm_agent;
`uvm_component_utils(fdi_agent)

fdi_driver fdi_drv;
fdi_monitor fdi_mon;
fdi_sequencer fdi_seqr;

fdi_agt_config fdi_cfg;

fdi_credit_manager credit_mgr;

function new(string name="fdi_agent",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
if(!uvm_config_db#(fdi_agt_config)::get(this,"","fdi_agt_config",fdi_cfg))
`uvm_fatal("FATAL","FROM FDI_AGENT")
fdi_mon=fdi_monitor::type_id::create("fdi_mon",this);

credit_mgr =fdi_credit_manager::type_id::create("credit_mgr",this);
uvm_config_db#(fdi_credit_manager):: set(this, "*", "fdi_credit_manager" ,credit_mgr); 



if(fdi_cfg.is_active)
begin
fdi_drv=fdi_driver::type_id::create("fdi_drv",this);
fdi_seqr=fdi_sequencer::type_id::create("fdi_seqr",this);
end
endfunction
endclass