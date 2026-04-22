class single_rw_virtual_seq extends sub_sequence;
	`uvm_object_utils(single_rw_virtual_seq)
	
	fdi_init_seqs init_seqh;
	
	single_rw_seq sin_rw_seqh0;
	single_rw_seq sin_rw_seqh1;
	
	//invalid_mngr_seq inv_mgr_seqh0;
	//invalid_mngr_seq inv_mgr_seqh1;
	
	function new(string name="single_rw_virtual_seq");
		super.new(name);
	endfunction
	
	task body();
		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		sin_rw_seqh0 = single_rw_seq::type_id::create("sin_rw_seqh0");
		sin_rw_seqh1 = single_rw_seq::type_id::create("sin_rw_seqh1");
		
		//inv_mgr_seqh0 = invalid_mngr_seq::type_id::create("inv_mgr_seqh0");
		//inv_mgr_seqh1 = invalid_mngr_seq::type_id::create("inv_mgr_seqh1");
		begin
		  init_seqh.start(fdi_seqr);
		 fork
		  sin_rw_seqh0.start(sub_sqr0);
		  sin_rw_seqh1.start(sub_sqr1);
		 
		  // inv_mgr_seqh0.start(mgr_seqr0);
		  //inv_mgr_seqh1.start(mgr_seqr1);
		 
		 join
	endtask
	
endclass