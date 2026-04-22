class single_rw_seq extends sub_sequence;
	`uvm_object_utils(single_rw_seq)
	axi_xtn txn;
	
	function new(string name="single_rw_seq");
		super.new(name);
	endfunction
	
	task body();
		begin
			txn=axi_xtn::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass