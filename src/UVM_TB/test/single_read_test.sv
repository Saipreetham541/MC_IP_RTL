class single_read_test extends axfdi_test;
	`uvm_component_utils(single_read_test)
	
	single_read_virtual_seq sin_rd_vir_seqh;

	
	function new(string name="single_read_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			sin_rd_vir_seqh=single_read_virtual_seq::type_id::create("sin_rd_vir_seqh");
			sin_rd_vir_seqh.start(env.vseqrh);
		phase.drop_objection(this);
	endtask
	
endclass