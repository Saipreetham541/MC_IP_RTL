class fdi_data_virtual_seq extends virtual_seq;
	`uvm_object_utils(fdi_data_virtual_seq)
	
	fdi_init_seqs init_seqh;
	fdi_data_seqs f_data_seqh;
	mgr_axi_req_ready_seq mgr_req_rdy;
virtual_seqr vseqrh;
	function new(string name="fdi_data_virtual_seq");
		super.new(name);
	endfunction
	
	task body();
	if(!$cast(vseqrh, m_sequencer))
			`uvm_error("error","from base v_seq")
		init_seqh = fdi_init_seqs::type_id::create("init_seqh");
		
		begin
				
			init_seqh.start(vseqrh.fdi_seqr);
			#20;
				repeat(1)
				 	begin
						f_data_seqh = fdi_data_seqs::type_id::create("f_data_seqh");
						f_data_seqh.start(vseqrh.fdi_seqr);
						mgr_req_rdy = mgr_axi_req_ready_seq::type_id::create("mgr_req_rdy");
						mgr_req_rdy.start(vseqrh.mgr_seqr0);
						
					end
		end

	endtask
	
endclass

