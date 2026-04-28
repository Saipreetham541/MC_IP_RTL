//fdi_agent-config
class fdi_agt_config extends uvm_object;
`uvm_object_utils(fdi_agt_config)
//fdi-interface declaration
virtual fdi_interface fdi_intf;
uvm_active_passive_enum is_active;

function new(string name="fdi_agt_config");
super.new(name);
endfunction
endclass