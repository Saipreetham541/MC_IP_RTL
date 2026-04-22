class standalone_credit_virtual_seq extends virtual_sequence;
	`uvm_object_utils(standalone_credit_virtual_seq)
	
	fdi_init_seqs init_seqh;
		
	single_rw_seq axi_rw_seqh0;
	single_rw_seq axi_rw_seqh1;
	fdi_data_seqs fdi_d_seqh;
	fdi_standalone_credit_rtn_seqs fdi_sd_seqh;
	
	rand int temp;
	constraint c1{temp inside{0,1};}
	int unsigned count=0;
	
	function new(string name="standalone_credit_virtual_seq");
		super.new(name);
	endfunction
	
	task body();

		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		
		axi_rw_seqh0 = single_rw_seq::type_id::create("axi_rw_seqh0");
		axi_rw_seqh1 = single_rw_seq::type_id::create("axi_rw_seqh1");
		
		fdi_d_seqh=fdi_data_seqs::type_id::create("fdi_d_seqh");
		fdi_sd_seqh = fdi_standalone_credit_rtn_seqs::type_id::create("fdi_sd_seqh");
		
		begin
			init_seqh.start(fdi_seqr);
			
			repeat(33)
				begin
					if(count<16) 
						begin
							fork 
								begin
									if(temp==0)
										axi_rw_seqh0.start(sub_sqr0);
									else 
										axi_rw_seqh1.start(sub_sqr1);
								end
								
										fdi_d_seqh.start(fdi_seqr);
							join
						count=count+1;
						end
			
			
					else
						begin
							fork
								
								fdi_sd_seqh.start(fdi_seqr);
							join
							count=0;
						end
				end
	endtask
	
endclass