class virtual_seq  extends uvm_sequence #(uvm_sequence_item);
`uvm_object_utils(virtual_seq)

	// sub_seqs
	
	//write_sub_seqs wss0, wss1;
	
	// mgr_seqs
	
	//mgr_seqs mgr_seqsh0, mgr_seqsh1 ;
	
	//virtual_seqr vseqrh;
	
	function new(string name="virtual_seq");
		super.new(name);
	endfunction
	
	task body();
	
		/* if(!$cast(vseqrh, m_sequencer))
			`uvm_error("error","from base v_seq") */
		
	endtask
endclass