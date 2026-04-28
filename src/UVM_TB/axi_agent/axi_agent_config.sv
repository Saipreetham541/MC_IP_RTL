//axi_agt_config
class axi_agt_config extends uvm_object;
`uvm_object_utils(axi_agt_config)
//axi_subordinate interface declaration
virtual mgr_interface mgr_intf;
virtual sub_interface sub_intf;
uvm_active_passive_enum is_active;
typedef enum {MGR, SUB} axi_role_e;
axi_role_e role;
function new(string name="axi_agt_config");
super.new(name);
endfunction

endclass