class fdi_init_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_init_seqs)
	fdi_pkt_item fditxn;
	
	function new(string name="fdi_init_seqs");
		super.new(name);
	endfunction
	
	task body();
		int credit[2]={32, 32};
		
		foreach(credit[vcn]) 
			begin
			fditxn=fdi_pkt_item:: type_id:: create("fditxn");
			start_item(fditxn);
			assert(fditxn.randomize() with{fditxn.opcode==4'h5;
									  fditxn.credit_rtn_vcn==vcn;
									  fditxn.credit_rtn_cnt==credit[vcn];});
			finish_item(fditxn);
			end
	endtask
endclass


	

