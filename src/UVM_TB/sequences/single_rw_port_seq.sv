class single_rw_seq extends uvm_sequence#(axi4_seq_item);
	`uvm_object_utils(single_rw_seq)
	axi4_seq_item txn;
	
	function new(string name="single_rw_seq");
		super.new(name);
	endfunction
	
	task body();
		begin
			txn=axi4_seq_item::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass