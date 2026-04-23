class fdi_inline_credit_rtn_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_inline_credit_rtn_seqs)

	fdi_pkt_item fditxn;

	function new(string name="fdi_inline_credit_rtn_seqs0");
		super.new(name);
	endfunction	
	
	task body();
		begin
			fditxn = fdi_pkt_item::type_id::create("credit_txn");
			start_item(fditxn);
			assert(fditxn.randomize() with {trdy == 1;
											startofpkt == 1;
											endofpkt   == 1;
											opcode inside {[0:3]};
											vcn ==00;
											credit_rtn_cnt == 16;
											credit_rtn_vcn ==0;
											});
			finish_item(fditxn);
		end
	endtask
	
endclass