class fdi_data_seqs extends uvm_sequence#(fdi_pkt_item);
	`uvm_object_utils(fdi_data_seqs)

	fdi_pkt_item fditxn;

	function new(string name="fdi_data_seqs");
		super.new(name);
	endfunction	
	
	task body();
		begin
			fditxn = fdi_pkt_item::type_id::create("data_txn");
			start_item(fditxn);
			if (!fditxn.randomize() with {trdy == 1;
											startofpkt == 1;
											endofpkt   == 1;
											opcode == 0;
											vcn ==0;
											burst_len ==0;
											credit_rtn_cnt == 0;
											credit_rtn_vcn ==0;
											port_id == 0;
											backpressure_cycles == '0;
											resp == '0;
											data.size() == 216;
											foreach (data[i]) {
												if (i == 215)
												data[i] == 8'hAA;
												else
												data[i] == 8'h00;
											}
											}) begin
        `uvm_fatal("RAND_FAIL", "FDI txn randomization failed")
      end
			finish_item(fditxn);
		end
	endtask
	
endclass