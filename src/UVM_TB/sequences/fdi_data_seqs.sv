class fdi_data_seqs extends sub_sequence;
	`uvm_object_utils(fdi_data_seqs)

	fdi_xtn fditxn;

	function new(string name="fdi_data_seqs");
		super.new(name);
	endfunction	
	
	task body();
		begin
			fditxn = fdi_xtn::type_id::create("data_txn");
			start_item(fditxn);
			assert(fditxn.randomize() with {trdy == 1;
											startofpkt == 1;
											endofpkt   == 1;
											opcode inside {[0:3]};
											vcn ==0;
											credit_rtn_cnt == 0;
											credit_rtn_vcn ==0;
											});
			finish_item(fditxn);
		end
	endtask
	
endclass