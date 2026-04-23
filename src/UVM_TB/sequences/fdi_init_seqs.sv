class fdi_init_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_init_seqs)
	fdi_pkt_item fditxn;
	
	function new(string name="fdi_init_seqs");
		super.new(name);
	endfunction
	
	task body();
		int credit[2]='{32, 32};
		
		foreach(credit[i]) 
			begin
			fditxn=fdi_pkt_item:: type_id:: create("fditxn");
			$display("seqs start");
			start_item(fditxn);
			assert(fditxn.randomize() with{opcode==4'h5;
									  credit_rtn_vcn=='0;
									  credit_rtn_cnt==6'd32;});
								fditxn.print();
								
			finish_item(fditxn);
			$display("seqs end");
			end
	endtask
endclass


	

