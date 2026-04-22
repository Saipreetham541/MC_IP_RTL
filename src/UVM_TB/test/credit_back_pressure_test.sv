class credit_back_pressure_test extends axfdi_test;
	`uvm_component_utils(credit_back_pressure_test)
	
	credit_back_pressure_virtual_seq cre_bp_vir_seqh;
	
	function new(string name="credit_back_pressure_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			cre_bp_vir_seqh=credit_back_pressure_virtual_seq::type_id::create("cre_bp_vir_seqh");
			cre_bp_vir_seqh.start(env.v_seqrh);
		phase.drop_objection(this);
	endtask
	
endclass