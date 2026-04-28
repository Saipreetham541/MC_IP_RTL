class credit_back_pressure_virtual_seq extends virtual_seq;
	`uvm_object_utils(credit_back_pressure_virtual_seq)
	
	fdi_init_seqs init_seqh;
		
	axi_back_pressure_seq axi_bp_seqh0;
	axi_back_pressure_seq axi_bp_seqh1;
	
	fdi_back_pressure_seqs fdi_bp_seqh;
	virtual_seqr vseqrh;
	
	function new(string name="credit_back_pressure_virtual_seq");
		super.new(name);
	endfunction
	
	task body();

		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		
		axi_bp_seqh0 = axi_back_pressure_seq::type_id::create("axi_bp_seqh0");
		axi_bp_seqh1 = axi_back_pressure_seq::type_id::create("axi_bp_seqh1");
		
		fdi_bp_seqh = fdi_back_pressure_seqs::type_id::create("fdi_bp_seqh");
		begin
				
				init_seqh.start(vseqrh.fdi_seqr);
				
			fork
			    axi_bp_seqh0.start(vseqrh.sub_seqr0);
				axi_bp_seqh1.start(vseqrh.sub_seqr1);
				
				fdi_bp_seqh.start(vseqrh.fdi_seqr);
			join
		end
	endtask
	
endclass