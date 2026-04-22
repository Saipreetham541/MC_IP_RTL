class fdi_init_seqs extends fdi_sequence;
	`uvm_object_utils(fdi_init_seqs)
	fdi_xtn fditxn;
	
	function new(string name="fdi_init_seqs");
		super.new(name);
	endfunction
	
	task body();
		int credit[2]={32, 32};
		
		foreach(credit[vcn]) 
			begin
			fditxn=fdi_xtn:: type_id:: create("fditxn");
			start_item(fditxn);
			assert(fditxn.randomize() with{fditxn.opcode==4'h5;
									  fditxn.credit_rtn_vcn==vcn;
									  fditxn.credit_rtn_cnt==credit[vcn];});
			finish_item(fditxn);
			end
	endtask
endclass


	

