class credit_starve_virtual_seq extends virtual_seq;
	`uvm_object_utils(credit_starve_virtual_seq)
	
	fdi_init_seqs init_seqh;
		
	credit_starve_axi_seq axi__seqh0;
	credit_starve_axi_seq axi__seqh1;
		virtual_seqr vseqrh;
	
	fdi_credit_starve_seqs fdi_cre_strh;
	
	function new(string name="credit_starve_virtual_seq");
		super.new(name);
	endfunction
	
	task body();

		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		
		axi__seqh0 = credit_starve_axi_seq::type_id::create("axi__seqh0");
		axi__seqh1 = credit_starve_axi_seq::type_id::create("axi__seqh1");
		
		fdi_cre_strh = fdi_credit_starve_seqs::type_id::create("fdi_cre_strh");
		begin
				
				init_seqh.start(vseqrh.fdi_seqr);
			fork
			    axi__seqh0.start(vseqrh.sub_seqr0);
				axi__seqh1.start(vseqrh.sub_seqr1);
				fdi_cre_strh.start(vseqrh.fdi_seqr);
			join
		end
	endtask
	
endclass