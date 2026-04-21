//fdi_sequencer
 
 class fdi_sequencer extends uvm_sequencer;
`uvm_component_utils(fdi_sequencer)
function new(string name="fdi_sequencer",uvm_component parent);
super.new(name,parent);
endfunction
endclass