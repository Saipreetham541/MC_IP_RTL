//apb_agent-config
class apb_agt_config extends uvm_object;
`uvm_object_utils(apb_agt_config)
//declaration of apb_interface
virtual apb_interface apb_intf;
uvm_active_passive_enum is_active;

function new(string name="apb_agt_config");
super.new(name);
endfunction
endclass
