class credit_starve_test extends axfdi_test;
	`uvm_component_utils(credit_starve_test)
	
	credit_starve_virtual_seq cre_star_vir_seqh;
	
	function new(string name="credit_starve_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			cre_star_vir_seqh=credit_starve_virtual_seq::type_id::create("cre_star_vir_seqh");
			cre_star_vir_seqh.start(env.vseqrh);
		phase.drop_objection(this);
	endtask
	
endclass