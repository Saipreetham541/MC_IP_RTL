class standalone_credit_test extends axfdi_test;
	`uvm_component_utils(standalone_credit_test)
	
	standalone_credit_virtual_seq sd_cre_vir_seqh;
	
	function new(string name="standalone_credit_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			sd_cre_vir_seqh=standalone_credit_virtual_seq::type_id::create("sd_cre_vir_seqh");
			sd_cre_vir_seqh.start(env.v_seqrh);
		phase.drop_objection(this);
	endtask
	
endclass