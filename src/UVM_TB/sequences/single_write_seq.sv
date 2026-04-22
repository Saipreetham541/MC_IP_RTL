class single_write_seq extends uvm_sequence #(axi4_seq_item);
	`uvm_object_utils(single_write_seq)
	axi_xtn txn;
	
	function new(string name="single_write_seq");
		super.new(name);
	endfunction
	
	task body();
		begin
			txn=axi_xtn::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{txn.axn_type==0;
										len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass