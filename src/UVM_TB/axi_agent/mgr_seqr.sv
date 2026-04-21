
//mgr-sequencer
class mgr_sequencer extends uvm_sequencer;
`uvm_component_utils(mgr_sequencer)
function new(string name="mgr_sequencer",uvm_component parent);
super.new(name,parent);
endfunction
endclass