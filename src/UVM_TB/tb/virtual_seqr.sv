class virtual_seqr extends uvm_sequencer #(uvm_sequence_item);
	`uvm_component_utils(virtual_seqr)
	
sub_sequencer sub_seqr0;
mgr_sequencer mgr_seqr0;

sub_sequencer sub_seqr1;
mgr_sequencer mgr_seqr1;

fdi_sequencer fdi_seqr;
	
function new (string name="virtual_seqr",uvm_component parent);
	super.new(name, parent);
endfunction

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
endfunction


	
endclass






