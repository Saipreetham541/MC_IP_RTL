class single_write_virtual_seq extends virtual_seq;
	`uvm_object_utils(single_write_virtual_seq)
	
	fdi_init_seqs init_seqh;
		
	single_write_seq sin_wr_seqh0;
	single_write_seq sin_wr_seqh1;
		virtual_seqr vseqrh;
	//invalid_mngr_seq inv_mgr_seqh0;
	//invalid_mngr_seq inv_mgr_seqh1;
	

	
	function new(string name="single_write_virtual_seq");
		super.new(name);
	endfunction
	
	task body();

		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		
		sin_wr_seqh0 = single_write_seq::type_id::create("sin_wr_seqh0");
		sin_wr_seqh1 = single_write_seq::type_id::create("sin_wr_seqh1");
		
		//inv_mgr_seqh0 = invalid_mngr_seq::type_id::create("inv_mgr_seqh0");
		//inv_mgr_seqh1 = invalid_mngr_seq::type_id::create("inv_mgr_seqh1");
		begin
				
				init_seqh.start(vseqrh.fdi_seqr);
			fork
			    sin_wr_seqh0.start(vseqrh.sub_seqr0);//vserh.seqr
				sin_wr_seqh1.start(vseqrh.sub_seqr1);
		 
				//inv_mgr_seqh0.start(mgr_seqr0);
				//inv_mgr_seqh1.start(mgr_seqr1);
			join
		end
	endtask
	
endclass