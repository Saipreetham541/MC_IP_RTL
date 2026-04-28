//sub_sequencer
 
 class sub_sequencer extends uvm_sequencer #(axi4_seq_item);
`uvm_component_utils(sub_sequencer)
function new(string name="sub_sequencer",uvm_component parent);
super.new(name,parent);
endfunction
endclass