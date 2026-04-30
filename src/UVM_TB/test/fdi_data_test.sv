class fdi_data_test extends axfdi_test;
	`uvm_component_utils(fdi_data_test)
	
	fdi_data_virtual_seq f_d_vir_seqh;
	
	function new(string name="fdi_data_test", uvm_component parent);
		super.new(name,parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		$display("extended:single_write_test");
		agt_cfg[0].role=axi_agt_config::MGR;
		agt_cfg[1].role=axi_agt_config::MGR;
		agt_cfg[0].typ=axi_agt_config::REQ;

	endfunction
	
	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		$display("raise objection started");
		
			phase.raise_objection(this);
				f_d_vir_seqh=fdi_data_virtual_seq::type_id::create("f_d_vir_seqh");
				f_d_vir_seqh.start(env.vseqrh);
				#300;
			phase.drop_objection(this);
	endtask
	
endclass