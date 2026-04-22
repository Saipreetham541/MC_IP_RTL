class single_rw_test extends axfdi_test;
	`uvm_component_utils(single_rw_test)
	
	single_rw_virtual_seq sin_rw_vir_seqh;
	
	function new(string name="single_rw_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			sin_rw_vir_seqh=single_rw_virtual_seq::type_id::create("sin_rw_vir_seqh");
			sin_rw_vir_seqh.start(env.vseqrh);
		phase.drop_objection(this);
	endtask
	
endclass