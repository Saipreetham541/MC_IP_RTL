class inline_credit_test extends axfdi_test;
	`uvm_component_utils(inline_credit_test)
	
	inline_credit_virtual_seq inline_cre_vir_seqh;
	
	function new(string name="inline_credit_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			inline_cre_vir_seqh=inline_credit_virtual_seq::type_id::create("inline_cre_vir_seqh");
			inline_cre_vir_seqh.start(env.v_seqrh);
		phase.drop_objection(this);
	endtask
	
endclass