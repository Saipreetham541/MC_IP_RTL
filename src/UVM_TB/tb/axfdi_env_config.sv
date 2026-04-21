//env_config

class env_config extends uvm_object;
`uvm_object_utils(env_config)


int no_of_axi_agts;


axi_agt_config agt_cfg[];
fdi_agt_config fdi_cfg;
apb_agt_config apb_cfg;

function new(string name="env_config");
super.new(name);
endfunction

endclass