class single_read_seq extends sub_sequence;
	`uvm_object_utils(single_read_seq)
	axi_xtn txn;
	
	function new(string name="single_read_seq");
		super.new(name);
	endfunction
	
	task body();
		begin
			txn=axi_xtn::type_id::create("txn");
			start_item(txn);
			assert(txn.randomize() with{txn.axn_type==1;
										len==0;
										burst==2'b01;
										});
			finish_item(txn);
		end
	endtask
endclass