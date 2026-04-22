class single_write_test extends axfdi_test;
	`uvm_component_utils(single_write_test)
	
	single_write_virtual_seq sin_wr_vir_seqh;
	
	function new(string name="single_write_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			sin_wr_vir_seqh=single_write_virtual_seq::type_id::create("sin_wr_vir_seqh");
			sin_wr_vir_seqh.start(env.v_seqrh);
		phase.drop_objection(this);
	endtask
	
endclass